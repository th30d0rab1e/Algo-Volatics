var con = require('mssql');
const position = require('@alpacahq/alpaca-trade-api/lib/resources/position');

var config = require('./config.js').dbConfig;

var logIt = 0;

var connected = true;
con.connect(config).then(function () {
    var request = new con.Request();

    request.query('SELECT 1').then(function (record) {
        log("Connection", "Succeeded")
        //con.close();
    }).catch(function (err) {
        log("NOT connected ERROR CODE: MARIE", err);
        //con.close();
    })
}).catch(function (err) {
    log("NOT Connected ERROR CODE: SAM", err);
})

function log (type, thingToConsoleLog) {
    if (logIt == 1){
        console.log(type, thingToConsoleLog);
    }
}

con.liquidate = async function () {
    try {
        return await executeQuery("EXEC LiquidatePositions;")
    } catch (error) {
        console.log("liquidate()", error);
    }
}

con.insertPositions = async function (positions) {
    try {
        let query = "TRUNCATE TABLE BULK_Position;";

        for (i=0; i<positions.length; i++){
            let stockName = positions[i].symbol;
            let currentPrice = positions[i].current_price;
            let entryPrice = positions[i].avg_entry_price;

            query += "INSERT INTO BULK_Position VALUES ('"+stockName+"', "+currentPrice+", "+entryPrice+");";
        }
        await executeQuery(query);
    } catch (error) {
        console.log("insertPositions()", positions)
    }
}

con.getTradeCalculation = async function () {
    try {
        var query = "exec TradeCalculation;";
        var trades =  await executeQuery(query);
        return trades;
    } catch (error) {
        console.log("getTradeCalculation()", error);
    }
}

con.insertBalance = async function (balance) {
    try {
        var query = "UPDATE Config SET Value = CAST(" + balance + " as varchar) WHERE Description = 'Balance';";
        await executeQuery(query);
    } catch (error) {
        console.log("insertBalance()", error);
    }
}

con.insertOrders  = async function (orders) {
    try {
        if(orders){
            let query = "TRUNCATE TABLE BULK_Orders;";
            for(i=0;i<orders.length;i++){
                query += "INSERT INTO Bulk_Orders (StockName, Status, BuyOrSell, OrderType, Shares, ExpireType, Price, ClientOrderID) VALUES ('" + orders[i].StockName + "','" + orders[i].Status + "','" + orders[i].BuyOrSell + "','" + orders[i].OrderType + "'," +  orders[i].Shares + ",'" + orders[i].ExpireType + "'," + orders[i].Price + ",'" + orders[i].ClientOrderID + "' );" 
            }
            query += "exec UpsertOrders;"
            await executeQuery(query);
        }
    } catch (error) {
        console.log("insertOrders", error);
    }
}

con.updateImitationProfit = async function (symbol, profit, hits) {
        try {
            let pool = await con.connect(config);
            let result = await pool.request()
                .input('Symbol', con.VarChar(50), symbol)
                .input('Profit', con.Float, profit)
                .input('Hits', con.Int, hits)
                .execute('Upd_Imitation')

            
            //con.close();
        } catch (err) {
            console.log("err updateImitationProfit", err)
            //con.close();
            
        }
    
}

async function executeQuery(query){
        try {
            log("Mackenzie test query", query);
            let pool = await con.connect(config)
            let result = await pool.request()
                .query(query)
                
            return result.recordset;
        } catch (err) {
            console.log("executeQuery()", err);
        }
}


con.drainPool = async function () {
    try {
        con.close()
    } catch (error) {
        console.log("drainPool()", error)
    }
}

con.downloadHistory = async function (history) {
    try {
        var query = "TRUNCATE TABLE BULK_HISTORY;";
        for (i=0;i<history.length;i++){
            query += "INSERT INTO BULK_History (StockName, Price, DateTraded) VALUES ( '" + history[i].StockName + "', " + history[i].Price + ", '" + history[i].Date + "' );"
        }

        await executeQuery(query);
        let averages = await executeQuery("exec UpdateAverageStock;")

        return averages[0];
    } catch (error) {
        log("Emily", error)
    }
}

con.getLastModifiedStock = async function () {
    try {
        let pool = await con.connect(config);
        let result = await pool.request()
            .execute('LastModifiedStock');
        log("Jena get", result)
        //con.close();
        return result.recordset;
    } catch (err) {
        log(" Taylor", err)
        //return err;
    }
}

con.downloadStocks = async function (data) {
    log("Patience", data)
    try {
        var query = "TRUNCATE TABLE BULK_STOCK;";
        for(i=0;i<data.length;i++){
            var name = data[i].StockName;
            var active = data[i].Active;
            var currency = data[i].Currency;
            if(active){
                active = 1;
            } else {
                active = 0;
            }
            query += "INSERT INTO BULK_Stock VALUES ( '" + name + "', " + active + ", '" + currency + "' );"
        }
        await executeQuery(query);
        await executeQuery("EXEC UpsertStock;");

    } catch (error) {
        log("download stocks", error);
    }
}

con.getAverage = async function (stockName) {
    try {
        var avg = await executeQuery("SELECT AvgPrice FROM Stock WHERE StockName = '" + stockName + "'");
        log("average", avg);
        return avg[0];
    } catch (error) {
        log("Laura", error);
    }
}

module.exports = con; 