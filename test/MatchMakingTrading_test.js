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
        let value = await tradingInstance.getPayOrderList(optionsAddr,"0x0000000000000000000000000000000000000000");
        console.log(value);
        tradingInstance.redeemPayOrder(optionsAddr,"0x0000000000000000000000000000000000000000",{from:accounts[2]});
        value = await tradingInstance.getPayOrderList(optionsAddr,"0x0000000000000000000000000000000000000000");
        console.log(value);

        await functionModule.OptionsManagerAddCollateral(managerAddress,optionsAddr,"0x0000000000000000000000000000000000000000",1200,300,accounts[3]);
        let token = await IERC20.at(optionsAddr);
        await token.approve(tradingInstance.address,220,{from:accounts[3]});
        await tradingInstance.sellOptionsToken(optionsAddr,220,"0x0000000000000000000000000000000000000000",{from:accounts[3]});
        value = await tradingInstance.getPayOrderList(optionsAddr,"0x0000000000000000000000000000000000000000");
        console.log(value);
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
        let value = await tradingInstance.getSellOrderList(optionsAddr,"0x0000000000000000000000000000000000000000");
        console.log(value);
        await tradingInstance.buyOptionsToken(optionsAddr,220,"0x0000000000000000000000000000000000000000",1000,{from:accounts[3],value:10000});
        value = await tradingInstance.getSellOrderList(optionsAddr,"0x0000000000000000000000000000000000000000");
        console.log(value);
    });

});