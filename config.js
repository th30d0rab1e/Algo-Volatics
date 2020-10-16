//SQL server Database
var dbconfig = {
    "server": 'localhost',
    "user": 'sa',
    "password": 'Nerdman11656680',
    "database": 'ALPACA',
    "port": 1433,
    "dialect": 'mssql',
    "dialectOptions": {
        "instanceName": 'SQLEXPRESS'
    },
    "requestTimeout": 1000000
};

const Alpaca = require('@alpacahq/alpaca-trade-api')

const apiConfig = new Alpaca({
    keyId: 'AK7MLZNKE5QJEU2QNW7J', 
    secretKey: '4Tl9AvnYZISEpbE1hr3D8bz3CCnUzvmCjaWjKc9n',
    paper: false,
})

module.exports = {apiConfig: apiConfig, dbConfig : dbconfig}; 
