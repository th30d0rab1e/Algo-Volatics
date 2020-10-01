//SQL server Database
var dbconfig = {
    "server": 'localhost',
    "user": 'sa',
    "password": 'Password',
    "database": 'ALPACA',
    "port": 1433,
    "dialect": 'mssql',
    "dialectOptions": {
        "instanceName": 'SQLEXPRESS'
    }
};

const Alpaca = require('@alpacahq/alpaca-trade-api')

const apiConfig = new Alpaca({
    keyId: 'ID', 
    secretKey: 'Key',
    paper: true,
})

module.exports = {apiConfig: apiConfig, dbConfig : dbconfig}; 
