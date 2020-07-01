const functionModule = require ("./testFunctions");
var OptionsManager = artifacts.require("OptionsManager");
var testCaseClass = require ("./testCases.js");
var checkBalance = require ("./checkBalance.js");
var IERC20 = artifacts.require("IERC20");
var FNXCoin = artifacts.require("FNXCoin");
const BN = require("bn.js");
let collateral0 = "0x0000000000000000000000000000000000000000";
contract('MatchMakingTrading', function (accounts){
    let testCase = new testCaseClass();

    it('MatchMakingTrading adding sell order', async function (){
        await testCase.migrateOptionsManager();
        let underlyingPrice = 100000;        
        let priceObj = {
            PriceList: [{
                address:collateral0,
                price:100000,
            }],
            underlyingAssets:[{
                id:1,
                price:underlyingPrice,
            }]
        }
        await testCase.setOraclePrice(priceObj);
        await testCase.migrateMatchMakingTrading();
        let expiration = Math.floor(Date.now()/1000)+36000;
        let amount = 1000000000;
        let fnxToken = await FNXCoin.deployed();     
        let mintAmount = new BN("10000000000000000000000000",10)
        for (var i=0;i<accounts.length;i++){
            await fnxToken.mint(accounts[i],mintAmount);
        }
        await testSellOrder(collateral0,collateral0,testCase,expiration,0,amount,accounts);
        await testSellOrder(collateral0,fnxToken.address,testCase,expiration,0,amount,accounts);
        await testSellOrder(fnxToken.address,collateral0,testCase,expiration,0,amount,accounts);
        await testSellOrder(fnxToken.address,fnxToken.address,testCase,expiration,0,amount,accounts);
        return
        var tradingInstance = await functionModule.migrateMatchMakingTrading();
        await tradingInstance.addWhiteList("0x0000000000000000000000000000000000000000");
        let managerAddress = await tradingInstance.getOptionsManagerAddress();
        let optionsAddr = await functionModule.OptionsManagerGetFirstOptionsToken(managerAddress,"0x0000000000000000000000000000000000000000",1,100,10000000000000,0); 
        let eligible = await tradingInstance.isEligibleOptionsToken(optionsAddr);
        console.log(optionsAddr,eligible);
        await tradingInstance.addPayOrder(optionsAddr,"0x0000000000000000000000000000000000000000",200,200,{from:accounts[2],value:500});
        let value = await tradingInstance.getPayOrderList(optionsAddr,"0x0000000000000000000000000000000000000000");
        console.log(value);
//        tradingInstance.redeemPayOrder(optionsAddr,"0x0000000000000000000000000000000000000000",{from:accounts[2]});
//        value = await tradingInstance.getPayOrderList(optionsAddr,"0x0000000000000000000000000000000000000000");
//        console.log(value);

        await functionModule.OptionsManagerAddCollateral(managerAddress,optionsAddr,"0x0000000000000000000000000000000000000000",1200,300,accounts[3]);
        let token = await IERC20.at(optionsAddr);
        await token.approve(tradingInstance.address,220,{from:accounts[3]});
        await tradingInstance.sellOptionsToken(optionsAddr,220,"0x0000000000000000000000000000000000000000",{from:accounts[3]});
        value = await tradingInstance.getPayOrderList(optionsAddr,"0x0000000000000000000000000000000000000000");
        console.log(value);
    });

    it('MatchMakingTrading adding buy order', async function (){
        await testCase.migrateOptionsManager();
        let underlyingPrice = 100000;        
        let priceObj = {
            PriceList: [{
                address:collateral0,
                price:100000,
            }],
            underlyingAssets:[{
                id:1,
                price:underlyingPrice,
            }]
        }
        await testCase.setOraclePrice(priceObj);
        await testCase.migrateMatchMakingTrading();
        let expiration = Math.floor(Date.now()/1000)+36000;
        let amount = 1000000000;
        let fnxToken = await FNXCoin.deployed();     
        let mintAmount = new BN("10000000000000000000000000",10)
        for (var i=0;i<accounts.length;i++){
            await fnxToken.mint(accounts[i],mintAmount);
        }
        await testBuyOrder(collateral0,collateral0,testCase,expiration,0,amount,accounts);
        await testBuyOrder(collateral0,fnxToken.address,testCase,expiration,0,amount,accounts);
        await testBuyOrder(fnxToken.address,collateral0,testCase,expiration,0,amount,accounts);
        await testBuyOrder(fnxToken.address,fnxToken.address,testCase,expiration,0,amount,accounts);
        return
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
async function testSellOrder(collateral,settlement,testCase,expiration,optType,amount,accounts){
    let underlyingAsset = 1;
    let strikePrices = await testCase.getTestStrikePriceList(underlyingAsset,optType);
    let checks = [new checkBalance("collateral",[],testCase.oracle)];
    if (collateral != collateral0){
        checks[0].token = await IERC20.at(collateral); 
    }
    for (var i=2;i<accounts.length;i++){
        checks[0].addAccount(accounts[i]);
    }
    checks[0].addAccount(testCase.manager.address);
    checks[0].addAccount(testCase.trading.address);
    await checks[0].beforeFunction();
    let checkSettle
    if (settlement != collateral){        
        checkSettle = new checkBalance("settlement",checks[0].accounts,testCase.oracle);
        if (settlement!= collateral0){
            checkSettle.token = await IERC20.at(settlement);
            
        }
        await checkSettle.beforeFunction();
        checks.push(checkSettle);
    }else{
        checkSettle = checks[0];
    }
    let ethCheck = (settlement!= collateral0) ? checks[0] : checkSettle;
    let strikePrice = strikePrices[0];
    let token = await testCase.createOptionsToken(collateral,underlyingAsset,expiration,optType,strikePrice,checks[0]);
    await testCase.oracle.setBuyOptionsPrice(token.address,60000);
    await testCase.oracle.setSellOptionsPrice(token.address,60000);
    let ercToken = await IERC20.at(token.address);
    let check1 = new checkBalance("token",checks[0].accounts,testCase.oracle,ercToken);
    await check1.beforeFunction();
    checks.push(check1);
    let needMint = await testCase.calCollateralToMintAmount(token.address,amount,optType)-100;
    for (var j=2;j<accounts.length;j++){
        let account = accounts[j];
        let txResult = await testCase.addCollateral(token.address,amount,needMint,account);
        await ethCheck.setTx(txResult);
        checks[0].addAccountCheckValue(account,-amount);
        checks[0].addAccountCheckValue(testCase.manager.address,amount);
        check1.addAccountCheckValue(account,needMint);
        let txs = await testCase.addSellOrder(token.address,settlement,needMint,account);
        await ethCheck.setTx(txs);
        check1.addAccountCheckValue(account,-needMint);
        check1.addAccountCheckValue(testCase.trading.address,needMint);
    }
    let sellList = await testCase.trading.getSellOrderList(token.address,settlement);
    let buyMint = Math.floor(needMint/2);
    for (var j=accounts.length-1;j>0;j--){
        let account = accounts[j];
        let fees = await testCase.calBuyOptionsToken(token.address,buyMint,settlement);
        console.log(fees)
        let txResult = await testCase.buyOptionsToken(token.address,buyMint,settlement,fees[0]+10,account);
        console.log(txResult[0].tx);
        await ethCheck.setTx(txResult);
        checkSettle.addAccountCheckValue(account,-fees[0]);
        checkSettle.addAccountCheckValue(testCase.trading.address,fees[1]);
        check1.addAccountCheckValue(account,buyMint);
        check1.addAccountCheckValue(testCase.trading.address,-buyMint);
    }
    let sellListNew = await testCase.trading.getSellOrderList(token.address,settlement);
    let priceMapNew = {}
    for (var i=0;i<sellListNew[0].length;i++){
        priceMapNew[sellListNew[0][i]+"_"+sellListNew[1][i]] = sellListNew[2][i]
    }
    for (var i=0;i<sellList[0].length;i++){
        let newPrice = priceMapNew[sellList[0][i]+"_"+sellList[1][i]];
        if (!newPrice){
            newPrice = 0;
        }
        let tokenAmount = sellList[2][i] - newPrice;
        if (tokenAmount == 0){
            continue;
        }
        let fees = await testCase.calBuyOptionsToken(token.address,tokenAmount,settlement);
        console.log(tokenAmount,fees)
        checkSettle.addAccountCheckValue(sellList[0][i],fees[2]);
    }

    for (var i=0;i<checks.length;i++){
        await checks[i].checkFunction();
    }
}
async function testBuyOrder(collateral,settlement,testCase,expiration,optType,amount,accounts){
    let underlyingAsset = 1;
    let strikePrices = await testCase.getTestStrikePriceList(underlyingAsset,optType);
    let checks = [new checkBalance("collateral",[],testCase.oracle)];
    if (collateral != collateral0){
        checks[0].token = await IERC20.at(collateral); 
    }
    for (var i=2;i<accounts.length;i++){
        checks[0].addAccount(accounts[i]);
    }
    checks[0].addAccount(testCase.manager.address);
    checks[0].addAccount(testCase.trading.address);
    await checks[0].beforeFunction();
    let checkSettle
    if (settlement != collateral){        
        checkSettle = new checkBalance("settlement",checks[0].accounts,testCase.oracle);
        if (settlement!= collateral0){
            checkSettle.token = await IERC20.at(settlement);
            
        }
        await checkSettle.beforeFunction();
        checks.push(checkSettle);
    }else{
        checkSettle = checks[0];
    }
    let ethCheck = (settlement!= collateral0) ? checks[0] : checkSettle;
    let strikePrice = strikePrices[0];
    let token = await testCase.createOptionsToken(collateral,underlyingAsset,expiration,optType,strikePrice,checks[0]);
    await testCase.oracle.setBuyOptionsPrice(token.address,60000);
    await testCase.oracle.setSellOptionsPrice(token.address,60000);
    let ercToken = await IERC20.at(token.address);
    let check1 = new checkBalance("token",checks[0].accounts,testCase.oracle,ercToken);
    await check1.beforeFunction();
    checks.push(check1);
    let needMint = await testCase.calCollateralToMintAmount(token.address,amount,optType)-100;
    let buyMint = Math.floor(needMint*2);
    for (var j=accounts.length-1;j>0;j--){
        let account = accounts[j];
        let fees = await testCase.calSellOptionsToken(token.address,buyMint,settlement);
        console.log(fees);
        let fee = fees[0]+20;
        let txResult = await testCase.addBuyOrder(token.address,settlement,fee,buyMint,account);
        await ethCheck.setTx(txResult);
        checkSettle.addAccountCheckValue(account,-fee);
        checkSettle.addAccountCheckValue(testCase.trading.address,fee);
    }
    let buyList = await testCase.trading.getPayOrderList(token.address,settlement);
    for (var j=2;j<accounts.length;j++){
        let account = accounts[j];
        let txResult = await testCase.addCollateral(token.address,amount,needMint,account);
        await ethCheck.setTx(txResult);
        checks[0].addAccountCheckValue(account,-amount);
        checks[0].addAccountCheckValue(testCase.manager.address,amount);
        check1.addAccountCheckValue(account,needMint);
        let txs = await testCase.sellOptionsToken(token.address,needMint,settlement,account);
        await ethCheck.setTx(txs);
        check1.addAccountCheckValue(account,-needMint);
        let fees = await testCase.calSellOptionsToken(token.address,needMint,settlement);
        checkSettle.addAccountCheckValue(account,fees[2]);
        checkSettle.addAccountCheckValue(testCase.trading.address,-fees[2]);
    }
    let buyListNew = await testCase.trading.getPayOrderList(token.address,settlement);
    let priceMapNew = {}
    for (var i=0;i<buyListNew[0].length;i++){
        priceMapNew[buyListNew[0][i]+"_"+buyListNew[1][i]] = [buyListNew[2][i],buyListNew[3][i]]
    }
    
    for (var i=0;i<buyList[0].length;i++){
        let newAmount = 0;
        if (priceMapNew[buyList[0][i]+"_"+buyList[1][i]]){
            newAmount = priceMapNew[buyList[0][i]+"_"+buyList[1][i]][0];
        }
        let tokenAmount = buyList[2][i] - newAmount;
        if (tokenAmount == 0){
            continue;
        }
        let fees = await testCase.calSellOptionsToken(token.address,tokenAmount,settlement);
        console.log(tokenAmount,fees)
        check1.addAccountCheckValue(buyList[0][i],tokenAmount);
        if (!priceMapNew[buyList[0][i]+"_"+buyList[1][i]]){
            leftSettle = buyList[3][i] - fees[0];
            checkSettle.addAccountCheckValue(buyList[0][i],leftSettle);
            checkSettle.addAccountCheckValue(testCase.trading.address,-leftSettle);
        }
    }

    for (var i=0;i<checks.length;i++){
        await checks[i].checkFunction();
    }
}