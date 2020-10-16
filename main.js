const multipleConfigs = require ('./config.js');
const api = multipleConfigs.apiConfig;
const db = require('./database.js');
const position = require('@alpacahq/alpaca-trade-api/lib/resources/position');

var importValues = {
    history : [],
    orders : [],
    newSymbols : [],
    stockToUpdate : "",
    buyingPower: 0,
    tradeCalculation : [],
    isMarketOpen: false,
    positions: []
}

main();

Date.prototype.addDays = function (days) {
    var date = new Date(this.valueOf());
    date.setDate(date.getDate() + days);
    return date;
}

async function fetchPositions () {
    try {
        let positions = await api.getPositions();
        return positions;
    } catch (error) {
        console.log("fetchPositions()", error);
    }
}

async function liquidate () {
    try {
        if(importValues.isMarketOpen){
            let positions = await db.liquidate();
            if(positions.length > 0) {
                await api.closePosition(positions[0].StockName);
                console.log("Liquidated", positions[0].StockName, "for $", positions[0].Profit$);
            }
        }
    } catch (error) {
        console.log("liquidate()", error);
    }
}

async function fetchMarketStatus () {
    try {
        let status =  await api.getClock();
        return status.is_open;
    } catch (error) {
        console.log("fetchMarketStatus()", error);
    }
}

async function fetchTradeCalculation() {
    try {
        let trades1 = await db.getTradeCalculation();
        return trades1;
    } catch (error) {
        console.log("fetchTradeCalculation", error);
    }
}

async function fetchOrders () {
    try {
        let date = new Date();
        date.setDate(date.getDate() - 10);
        date = date.toLocaleDateString();
        
        let orders = await api.getOrders({
            status: 'all', //'open' | 'closed' | 'all'
            after: date
        }) 

        //return an array in this format
        //{ StockName varchar(50), Status varchar(50), BuyOrSell varchar(50), OrderType varchar(50), Shares int, ExpireType varchar(50), Price, clientOrderID varchar(100) }

        let array = [];
        
        for(i=0;i<orders.length;i++){
            let stockName, status, buyOrSell, orderType, shares, expireType, price, clientOrderID;
            stockName = orders[i].symbol;
            status = orders[i].status;
            buyOrSell = orders[i].side;
            orderType = orders[i].type;
            shares = orders[i].qty;
            expireType = orders[i].time_in_force;
            if(orders[i].status == "filled"){
                price = orders[i].filled_avg_price;
            } else {
                price = orders[i].limit_price;
            }
            clientOrderID = orders[i].id;

            array.push( {StockName: stockName, Status: status, BuyOrSell: buyOrSell, OrderType: orderType, Shares: shares, ExpireType: expireType, Price: price, ClientOrderID: clientOrderID } )
        }

        return array;
        
    } catch (error) {
        console.log("fetchOrders()", error.message)
    }
}

function ToLocalDate (inDate) {
    var date = new Date();
    date.setTime(inDate.valueOf() - 60000 * inDate.getTimezoneOffset());
    return date;
}

async function main() {
    try {
        await setup();
        await downloadToDatabase();
        await imitate(importValues.history);
        await trade();
        //await liquidate();
        await db.drainPool();
    } catch (error) {
        console.log("main() ", error);
    }
}

async function fetchBalance () {
    try {
        let balance =  await api.getAccount();
        return balance.buying_power;
    } catch (error) {
        console.log("fetchBalance", error);
    }
}

async function trade() {
    try {
        if(importValues.isMarketOpen){
            importValues.tradeCalculation = await fetchTradeCalculation();
            let newOrders = importValues.tradeCalculation;
            if (newOrders.length > 0) { 
                let order = newOrders[0];
                await createOrder(order);
            }
        } 
    } catch (error) {
        console.log("trade()", error);
    }
}

async function createOrder (order) {
    try {
        await api.createOrder({
            symbol: order.StockName
            , type: order.OrderType
            , qty: order.Shares
            , side: order.Action
            , time_in_force: order.ExpireType
            , limit_price: order.PriceToTrade
        })
        console.log("Finished Trading.", order.StockName);
    } catch (error) {
        console.log("createOrder()", error)
    }
}

async function downloadToDatabase () {
    try {
        console.log("Downloading data to database...");
        //intialize 
        const couldPossiblyBeNewStocks = db.downloadStocks(importValues.newSymbols);
        const neededHistory = db.downloadHistory(importValues.history);
        const orders = db.insertOrders(importValues.orders);
        const balance = db.insertBalance(importValues.buyingPower);
        const positions = db.insertPositions(importValues.positions);

        //execute
        await couldPossiblyBeNewStocks;
        let averages = await neededHistory;
        await orders;
        await balance;
        await positions;
        
        importValues.stockToUpdate.HighAvg = averages.HighAvg;
        importValues.stockToUpdate.LowAvg = averages.LowAvg;

        console.log("Finished download.");
    } catch (error) {
        console.log("downloadToDatabase()", error)
    }
}

async function setup() {
    try {
        console.log("Loading API calls...");
        //intialize
        const fetchAccounts1 = fetchAccounts();
        const history = updateStock();
        const balance = fetchBalance();
        const orders = fetchOrders();
        const marketStatus = fetchMarketStatus();
        const positions = fetchPositions();

        //save values to importValues
        importValues.newSymbols = await fetchAccounts1;
        importValues.history = await history;
        importValues.buyingPower = await balance;
        importValues.orders = await orders;
        importValues.isMarketOpen = await marketStatus;
        importValues.positions = await positions;

        //console.log("import values", importValues.tradeCalculation);
        console.log("Finished loading.");

    } catch (error) {
        console.log("setup()", error);
    }
}

async function updateStock() {
    try {
        let liststock = await db.getLastModifiedStock();
        importValues.stockToUpdate  = liststock[0];
        
        //Get history
        var interval = '15Min' //'minute' | '1Min' | '5Min' | '15Min' | 'day' | '1D'
        var limit = 0; 
        var amountOfDays = 100
        var date = new Date();

        let history1 = await api.getBars(interval, importValues.stockToUpdate.StockName,
            {
                limit: limit
                , start: date.addDays(-amountOfDays).toISOString()
                , end: date.toISOString()
            }
        )
        let history = history1[importValues.stockToUpdate.StockName]
        
        //return an array in this format
        // {StockName varchar(50), Price decimal, Date datetime}
        //example
        //[ { StockName: 'AAPL', Price: 50, Date: '2020-01-01 09:28:29' }
        // { StockName: 'AAPL', Price: 1, Date: '2020-01-02 13:28:29' } ] 

        var array = [];
        for(i=0;i<history.length;i++){
            let formattedDate = new Date(history[i].startEpochTime * 1000);
            formattedDate = formattedDate.toLocaleString('en-GB', { hour12:false } )
            formattedDate = formattedDate.replace(",", "");
            
            array.push( {StockName: importValues.stockToUpdate.StockName, Price: history[i].openPrice, Date: formattedDate } )
            array.push( {StockName: importValues.stockToUpdate.StockName, Price: history[i].closePrice, Date: formattedDate } )
        }

        //7/18/2020 09:28:00
        return array;

    } catch (error) {
        console.log("updateStock", error)
    }
}

async function imitate(historyData) {
    
    //Example { StockName: 'ACAMU', Price: 11, Date: '7/28/2020 13:26:00' }

    try {
        if (historyData.length > 0) {
            var symbol = importValues.stockToUpdate.StockName;
            var total = 100000;
            var buyAvg = importValues.stockToUpdate.LowAvg
            var sellAvg = importValues.stockToUpdate.HighAvg
            var profit = 0;
            var hits = 0;
    
            var boughtStock = []; //fake collection of stocks that are bought
            for (i = 0; i < historyData.length; i++) { //for every row of history
                var row = historyData[i]
                //Sell
                if (boughtStock.length > 0 && row.Price > sellAvg) {
                    hits = hits +1;
                    for (j = 0; j < boughtStock.length; j++) {
                        total = total + row.Price;
                        profit = profit + (row.Price - boughtStock[j])
                        boughtStock.splice(j, 1)//sold it, remove it
                        //console.log("SOLD!", row.Price, profit, total, sellAvg)
                    }
                }
                //Buy
                if (row.Price <= total && row.Price < buyAvg) {
                    hits = hits +1;

                    while(total - row.Price > 0 ) {
                        //console.log("BOUGHT!", row.Price, profit, total, buyAvg)
                        boughtStock.push(row.Price); //imitated a bought stock
                        //Calculate Balance
                        total = total - row.Price;
                    }
                }
            }

            console.log("Imitation Finished.", symbol, "profit",profit, "hits", hits, "lengthHistory", historyData.length);
    
            //Update profits to database
            await db.updateImitationProfit(symbol, profit, hits);
            
        } else {
            console.log("No data imitation failed.")
        }
        
    } catch (error) {
        console.log("imitate()", error)
    }
}

async function fetchAccounts() {
    try {

    //Format this.obj.newStocks to fit array from brokerage account. This is needed for database insert eventually. 
        
        //example
        /*
        [ StockName (text/varchar), Active (boolean), Currency varchar(50)/text ]

        [ 'StockName1', 1, "USA" ]
        [ 'Stockname2', 0, "Mehico" ]
        */
       //console.log(accounts)

    var accounts = await api.getAssets({
        status: 'active',
        asset_class: 'us_equity'
    })

    var assets = [];
        Object.keys(accounts).forEach(key => {
            if (accounts[key].tradable == true) {
                assets.push( { StockName:accounts[key].symbol, Active: true, Currency: "US" } )
            }
        })

    return assets;

    } catch (error) {
        console.log("fetchAccounts", error)
    }
}
