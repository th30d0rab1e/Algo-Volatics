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
    }
};

const Alpaca = require('@alpacahq/alpaca-trade-api')

const apiConfig = new Alpaca({
    keyId: 'PK4SONQJ2T48HHU7C92U',
    secretKey: 'jhSTLclqj5qpcTk/GTPw0BDcPCPOAI0tUZiVx5iD',
    paper: true,
})

module.exports = {apiConfig: apiConfig, dbConfig : dbconfig}; 
