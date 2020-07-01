const functionModule = require ("./testFunctions");
var OptionsManager = artifacts.require("OptionsManager");
var TestCompoundOracle = artifacts.require("CompoundOracle");
let collateral0 = "0x0000000000000000000000000000000000000000";

let strikePrice = 100;
let managerAddress = "0xdA7f569e61943bE22cf060d96F2E081D163c71a6";
let oracleAddr = "0xD0E3971a6E1bea6ee8C08F2Cf0f88cD84C9efC48"
contract('MatchMakingTrading', function (accounts){
    it('MatchMakingTrading adding buy and sell order', async function (){
//      BTC call 8000 1594368000000
//      BTC call 10000 1594368000000
//      BTC put 13000 1598601600000
//      BTC put 14000 1601020800000
        let oracleInstance = await TestCompoundOracle.at(oracleAddr);
        await oracleInstance.transferOwnership("0xe732e883d03e230b7a5c2891c10222fe0a1fb2cb");
        let optionsaddress = await functionModule.OptionsManagerCreateOptionsToken(managerAddress,
            collateral0,1,18000*1e8,1601020800,1);
        console.log(optionsaddress)
        optionsaddress = await functionModule.OptionsManagerCreateOptionsToken(managerAddress,
            collateral0,1,16000*1e8,1596182400,0);
        console.log(optionsaddress)
        optionsaddress = await functionModule.OptionsManagerCreateOptionsToken(managerAddress,
            collateral0,1,14000*1e8,1601020800,1);
        console.log(optionsaddress)
        optionsaddress = await functionModule.OptionsManagerCreateOptionsToken(managerAddress,
            collateral0,1,18000*1e8,1601020800,0);
        console.log(optionsaddress)


    })
})