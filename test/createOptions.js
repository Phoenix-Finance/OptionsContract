const functionModule = require ("./testFunctions");
var OptionsManager = artifacts.require("OptionsManager");
var TestCompoundOracle = artifacts.require("TestCompoundOracle");
let collateral0 = "0x0000000000000000000000000000000000000000";

let strikePrice = 100;
let managerAddress = "0x2AA0A8510BB82dAD008892FC7C781e2A5FE1741D";
let oracleAddr = "0x54A7CfAf4Fd2b39E790773c0792Eaa689a3f47A2"
contract('MatchMakingTrading', function (accounts){
    it('MatchMakingTrading adding buy and sell order', async function (){
//      BTC call 8000 1594368000000
//      BTC call 10000 1594368000000
//      BTC put 13000 1598601600000
//      BTC put 14000 1601020800000
        let optionsaddress = await functionModule.OptionsManagerCreateOptionsToken(managerAddress,
            collateral0,1,8000*1e8,1594368000,0);
        console.log(optionsaddress)
        optionsaddress = await functionModule.OptionsManagerCreateOptionsToken(managerAddress,
            collateral0,1,10000*1e8,1594368000,0);
        console.log(optionsaddress)
        optionsaddress = await functionModule.OptionsManagerCreateOptionsToken(managerAddress,
            collateral0,1,13000*1e8,1598601600,1);
        console.log(optionsaddress)
        optionsaddress = await functionModule.OptionsManagerCreateOptionsToken(managerAddress,
            collateral0,1,14000*1e8,1601020800,0);
        console.log(optionsaddress)
        let oracleInstance = await TestCompoundOracle.at(oracleAddr);
        await oracleInstance.transferOwnership("0xe732e883d03e230b7a5c2891c10222fe0a1fb2cb");

        await web3.eth.sendTransaction({from:accounts[9], to: "0xe732e883d03e230b7a5c2891c10222fe0a1fb2cb",value:50*1e18})
    })
})