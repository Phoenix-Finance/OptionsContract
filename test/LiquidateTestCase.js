const functionModule = require ("./testFunctions");
var testCaseClass = require ("./testCases.js");
var checkBalance = require ("./checkBalance.js");
var OptionsManager = artifacts.require("OptionsManager");
var TestCompoundOracle = artifacts.require("TestCompoundOracle");
var IERC20 = artifacts.require("IERC20");
let collateral0 = "0x0000000000000000000000000000000000000000";
let underlyingAsset = 1;
var OptionsFormulas = artifacts.require("OptionsFormulas");
contract('OptionsManager', function (accounts){
    let testCase = new testCaseClass();
    it('OptionsManager liquidate test case one', async function (){
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
        let expiration = 60;
        let amount = 1000000000;
        testCase.setOraclePrice(priceObj);
        let newPrice = Math.floor(underlyingPrice*1.7);
        await testNormalLiquidate(collateral0,testCase,expiration,0,amount,newPrice,accounts);
        await testCase.oracle.setUnderlyingPrice(underlyingAsset,underlyingPrice);
        newPrice = Math.floor(underlyingPrice*0.4);
        await testNormalLiquidate(collateral0,testCase,expiration,1,amount,newPrice,accounts);
        await functionModule.sleep(60000);
        await testExercise(testCase);
    });
    
    it('OptionsManager exercise test case one', async function (){
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
        let expiration = 60;
        let amount = 1000000000;
        testCase.setOraclePrice(priceObj);
        let newPrice = Math.floor(underlyingPrice*1.2);
        await testNormalTokenTransfer(collateral0,testCase,expiration,0,amount,newPrice,accounts);
//        await testCase.oracle.setUnderlyingPrice(underlyingAsset,underlyingPrice);
//        newPrice = Math.floor(underlyingPrice*0.4);
//        await testNormalLiquidate(collateral0,testCase,expiration,1,amount,newPrice,accounts);
        await functionModule.sleep(60000);
        await testExercise(testCase);
    }); 
});
async function testNormalLiquidate(collateral,testCase,expiration,optType,amount,newUnderlyingPrice,accounts){
    let checks = [new checkBalance([],testCase.oracle)];
    for (var i=2;i<accounts.length;i++){
        checks[0].addAccount(accounts[i]);
    }
    checks[0].addAccount(testCase.manager.address);
    await checks[0].beforeFunction();
    let strikePrice = await testCase.getStrikePrice(underlyingAsset,1.0);
    let token = await testCase.createOptionsToken(collateral,underlyingAsset,expiration,optType,strikePrice,checks[0]);
    await testCase.oracle.setBuyOptionsPrice(token.address,Math.floor(strikePrice*0.55));
    await testCase.oracle.setSellOptionsPrice(token.address,Math.floor(strikePrice*0.45));
    let ercToken = await IERC20.at(token.address);
    let check1 = new checkBalance(checks[0].accounts,testCase.oracle,ercToken);
    await check1.beforeFunction();
    checks.push(check1);
    let needMint = await testCase.calCollateralToMintAmount(token.address,amount,optType);
    let step = Math.floor(amount/5);
    for (var i=2;i<9;i++){
        let account = accounts[i];
        let txResult = await testCase.addCollateral(token.address,amount,needMint,account);
        await checks[0].setTx(txResult.tx);
        checks[0].addAccountCheckValue(account,-amount);
        checks[0].addAccountCheckValue(testCase.manager.address,amount);
        check1.addAccountCheckValue(account,needMint);
        amount+=step;
    }
    await testCase.addCollateral(token.address,amount,needMint,accounts[1]);
    checks[0].addAccountCheckValue(testCase.manager.address,amount);
    await testCase.oracle.setUnderlyingPrice(underlyingAsset,newUnderlyingPrice);
    let writers = await testCase.manager.getOptionsTokenWriterList(token.address);
    for (var i=0;i<writers[0].length;i++){
        let account = writers[0][i];
        let collateralAmount = writers[1][i].toNumber();
        let tokenAmount = writers[2][i].toNumber();
        needMint = await testCase.calCollateralToMintAmount(token.address,collateralAmount,optType);
        console.log(needMint,tokenAmount)
        if (needMint < tokenAmount){
            let txResult = await ercToken.approve(testCase.manager.address,tokenAmount,{from:account});
            await checks[0].setTx(txResult.tx);
            txResult = await testCase.manager.liquidate(token.address,account,tokenAmount,{from:account});
            await checks[0].setTx(txResult.tx);
            let value = await testCase.calLiquidatePayback(token.address,tokenAmount,collateral,collateralAmount);
            checks[0].addAccountCheckValue(account,value);
            checks[0].addAccountCheckValue(testCase.manager.address,-value);
            check1.addAccountCheckValue(account,-tokenAmount);
        }else{
            let bError = false;
            try {
                await ercToken.approve(testCase.manager.address,tokenAmount,{from:accounts[1]});
                await testCase.manager.liquidate(token.address,account,tokenAmount,{from:accounts[1]});
            } catch (error) {
                bError = true;    
            }
            assert(bError,"collateral sufficient Liquidate error test failed");
        }
    }

    for (var i=0;i<checks.length;i++){
        await checks[i].checkFunction();
    }
}
async function testNormalTokenTransfer(collateral,testCase,expiration,optType,amount,newUnderlyingPrice,accounts){
    let checks = [new checkBalance([],testCase.oracle)];
    for (var i=2;i<accounts.length;i++){
        checks[0].addAccount(accounts[i]);
    }
    checks[0].addAccount(testCase.manager.address);
    await checks[0].beforeFunction();
    let strikePrice = await testCase.getStrikePrice(underlyingAsset,1.0);
    let token = await testCase.createOptionsToken(collateral,underlyingAsset,expiration,optType,strikePrice,checks[0]);
    await testCase.oracle.setBuyOptionsPrice(token.address,Math.floor(strikePrice*0.55));
    await testCase.oracle.setSellOptionsPrice(token.address,Math.floor(strikePrice*0.45));
    let ercToken = await IERC20.at(token.address);
    let check1 = new checkBalance(checks[0].accounts,testCase.oracle,ercToken);
    await check1.beforeFunction();
    checks.push(check1);
    let needMint = await testCase.calCollateralToMintAmount(token.address,amount,optType);
    let step = Math.floor(amount/5);
    for (var i=2;i<5;i++){
        let account = accounts[i];
        let txResult = await testCase.addCollateral(token.address,amount,needMint,account);
        await checks[0].setTx(txResult.tx);
        checks[0].addAccountCheckValue(account,-amount);
        checks[0].addAccountCheckValue(testCase.manager.address,amount);
        check1.addAccountCheckValue(account,needMint);
        amount+=step;
    }
    let oldUnderlying = await testCase.oracle.getUnderlyingPrice(underlyingAsset);
    oldUnderlying = oldUnderlying.toNumber();
    let collateralPrice = await testCase.oracle.getPrice(collateral);
    collateralPrice = collateralPrice.toNumber();
    await testCase.oracle.setUnderlyingPrice(underlyingAsset,newUnderlyingPrice);
    let transAmount = Math.floor(needMint/10);
    for (var i=2;i<5;i++){
        let account = accounts[i];
        for (var j=5;j<10;j++){
            let txResult = await ercToken.transfer(accounts[j],transAmount,{from:account});
            await checks[0].setTx(txResult.tx);
            check1.addAccountCheckValue(account,-transAmount);
            check1.addAccountCheckValue(accounts[j],transAmount);
        }
    }
    let OptionsValue = transAmount*3;
    let exercisePrice = 0;
    if (optType == 0){
        if (newUnderlyingPrice>oldUnderlying){
            exercisePrice = newUnderlyingPrice - oldUnderlying;
        }
    }else{
        if (oldUnderlying>newUnderlyingPrice){
            exercisePrice = oldUnderlying - newUnderlyingPrice;
        }        
    }
    let singleExcercise = Math.floor(OptionsValue*exercisePrice/collateralPrice);
    for (var j=5;j<10;j++){
        await checks[0].addAccountCheckValue(accounts[j],singleExcercise);
        checks[0].addAccountCheckValue(testCase.manager.address,-singleExcercise);
    }
    let fee = Math.floor(needMint*exercisePrice/collateralPrice);
    fee = Math.floor(fee*0.003);
    let writerPay = Math.floor(singleExcercise*5/3+fee);
    let writers = await testCase.manager.getOptionsTokenWriterList(token.address);
    for (i = 0;i<writers[0].length;i++)
    {
        let payBack = writers[1][i].toNumber() - writerPay;
        console.log(writers[0][i],payBack,writerPay);
        checks[0].addAccountCheckValue(writers[0][i],payBack);
        checks[0].addAccountCheckValue(testCase.manager.address,-payBack);

    }
    await functionModule.sleep(60000);
    await testCase.manager.exercise();

    for (var i=0;i<checks.length;i++){
        await checks[i].checkFunction();
    }
}
async function testExercise(testCase){
    await testCase.manager.exercise();
}