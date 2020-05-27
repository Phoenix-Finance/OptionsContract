const functionModule = require ("./testFunctions");
var OptionsManager = artifacts.require("OptionsManager");
var IERC20 = artifacts.require("IERC20");
contract('MatchMakingTrading', function (accounts){
    it('MatchMakingTrading adding pay order', async function (){
        var tradingInstance = await functionModule.migrateMatchMakingTrading();
        await tradingInstance.addWhiteList("0x0000000000000000000000000000000000000000");
        let managerAddress = await tradingInstance.getOptionsManagerAddress();
        let optionsAddr = await functionModule.OptionsManagerGetFirstOptionsToken(managerAddress,"0x0000000000000000000000000000000000000000",1,100,10000000000000,0);
        let eligible = await tradingInstance.isEligibleOptionsToken(optionsAddr);
        console.log(optionsAddr,eligible);
        await tradingInstance.addPayOrder(optionsAddr,"0x0000000000000000000000000000000000000000",200,200,{from:accounts[2],value:500});
    });
    it('MatchMakingTrading adding sell order', async function (){
        var tradingInstance = await functionModule.migrateMatchMakingTrading();
        await tradingInstance.addWhiteList("0x0000000000000000000000000000000000000000");
        let managerAddress = await tradingInstance.getOptionsManagerAddress();
        let optionsAddr = await functionModule.OptionsManagerGetFirstOptionsToken(managerAddress,"0x0000000000000000000000000000000000000000",1,100,10000000000000,0);
        let eligible = await tradingInstance.isEligibleOptionsToken(optionsAddr);
        console.log(optionsAddr,eligible);
        await functionModule.OptionsManagerAddCollateral(managerAddress,optionsAddr,"0x0000000000000000000000000000000000000000",1200,300,accounts[1]);
        let token = await IERC20.at(optionsAddr);
        await token.approve(tradingInstance.address,200,{from:accounts[1]});
        await tradingInstance.addSellOrder(optionsAddr,"0x0000000000000000000000000000000000000000",200,{from:accounts[1]});
    });

});