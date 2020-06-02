const functionModule = require ("./testFunctions");
var OptionsManager = artifacts.require("OptionsManager");
var TestCompoundOracle = artifacts.require("TestCompoundOracle");
var OptionsFormulas = artifacts.require("OptionsFormulas");
var IERC20 = artifacts.require("IERC20");
let collateral0 = "0x0000000000000000000000000000000000000000";
contract('MatchMakingTrading', function (accounts){
    it('MatchMakingTrading adding buy and sell order', async function (){
        let priceObj = {
            PriceList: [{
                address:collateral0,
                price:1000000,
            }],
            underlyingAssets:[{
                id:1,
                price:1000000,
            }]
        }
        let expiration = 36000;
        let amount = 1000000000;
        let sellPrice = 990000;
        let buyPrice = 1010000;
        var tradingInstance = await functionModule.migrateMatchMakingTrading();
        let managerAddress = await tradingInstance.getOptionsManagerAddress();
        console.log(managerAddress);
        let managerIns = await OptionsManager.at(managerAddress);
        await tradingInstance.addWhiteList(collateral0);
        let result = await Addcollateral(managerIns,collateral0,priceObj,expiration,0,amount,accounts[2]);
        let oracleAddr = await managerIns.getOracleAddress();
        let oracleInstance = await TestCompoundOracle.at(oracleAddr); 
        await oracleInstance.setSellOptionsPrice(result.token,sellPrice);
        await oracleInstance.setBuyOptionsPrice(result.token,buyPrice);
        await addSellOrder(tradingInstance,result.token,collateral0,amount/2,accounts[2]);
        await addPayOrder(tradingInstance,result.token,collateral0,amount/2,accounts[3]);
    });

    it('MatchMakingTrading sell options token', async function (){
        let priceObj = {
            PriceList: [{
                address:collateral0,
                price:1000000,
            }],
            underlyingAssets:[{
                id:1,
                price:1000000,
            }]
        }
        let expiration = 36000;
        let amount = 1000000000;
        let sellPrice = 990000;
        let buyPrice = 1010000;
        var tradingInstance = await functionModule.migrateMatchMakingTrading();
        let managerAddress = await tradingInstance.getOptionsManagerAddress();
        console.log(managerAddress);
        let managerIns = await OptionsManager.at(managerAddress);
        await tradingInstance.addWhiteList(collateral0);
        let result = await Addcollateral(managerIns,collateral0,priceObj,expiration,0,amount,accounts[9]);
        let oracleAddr = await managerIns.getOracleAddress();
        let oracleInstance = await TestCompoundOracle.at(oracleAddr); 
        await oracleInstance.setSellOptionsPrice(result.token,sellPrice);
        await oracleInstance.setBuyOptionsPrice(result.token,buyPrice);
        await addMultiPayOrder(tradingInstance,result.token,collateral0,amount/4+1000,accounts);
        sellPrice *= 1.1;
        console.log(sellPrice);
        await oracleInstance.setSellOptionsPrice(result.token,sellPrice);
        await sellOptionsToken(tradingInstance,result.token,collateral0,amount,accounts[9]);
        let orderList = await tradingInstance.getPayOrderList(result.token,collateral0);
        for (var i=0;i<orderList[0].length;i++){
            console.log(orderList[0][i],orderList[2][i].toNumber(),orderList[3][i].toNumber());
        }
        let fee = await tradingInstance.getFeeBalance(collateral0);
        let collateralPrice = await oracleInstance.getPrice(collateral0);
        let calFee = Math.floor(sellPrice*amount/collateralPrice);
        calFee = Math.floor(calFee*0.003)*2;
        console.log(fee.toNumber(),calFee);
        assert(Math.abs(fee.toNumber()-calFee)<10,"Manager Fee test failed");
    });

});
async function addPayOrder(tradingInstance,optionsAddr,settlements,buyAmount,account){
    let oracleAddr = await tradingInstance.getOracleAddress();
    let oracleInstance = await TestCompoundOracle.at(oracleAddr);  
    let sellPrice = await oracleInstance.getSellOptionsPrice(optionsAddr);
    let price = await oracleInstance.getPrice(settlements);
    console.log(sellPrice.toNumber(),price.toNumber());
    let deposit = Math.floor(sellPrice.toNumber()*buyAmount/price.toNumber());
    let feeRate = 0.003;
    let TransFee = Math.floor(deposit*feeRate);
    deposit += TransFee;
    let bError = false;
    try {
        await tradingInstance.addPayOrder(optionsAddr,settlements,deposit-2,buyAmount,{from:account,value:deposit-2});
    } catch (error) {
        bError = true;
    }
    assert(bError,"Settlement deposit insufficient test Failed");
    await tradingInstance.addPayOrder(optionsAddr,settlements,deposit,buyAmount,{from:account,value:deposit});
}
async function addMultiPayOrder(tradingInstance,optionsAddr,settlements,buyAmount,accounts){
    let oracleAddr = await tradingInstance.getOracleAddress();
    let oracleInstance = await TestCompoundOracle.at(oracleAddr);  
    let sellPrice = await oracleInstance.getSellOptionsPrice(optionsAddr);
    let price = await oracleInstance.getPrice(settlements);
    console.log(sellPrice.toNumber(),price.toNumber());
    let deposit = Math.floor(sellPrice.toNumber()*buyAmount/price.toNumber());
    let feeRate = 0.003;
    let TransFee = Math.floor(deposit*feeRate);
    deposit += TransFee;
    let testDeposit = deposit;
    for (var i=0;i<6;i++){
        await tradingInstance.addPayOrder(optionsAddr,settlements,deposit,buyAmount,{from:accounts[i+1],value:deposit});
        deposit += TransFee*50;
    }
    let orderList = await tradingInstance.getPayOrderList(optionsAddr,settlements);
    assert.equal(orderList[0].length,6,"add payorder test failed");
    for (var i=0;i<6;i++){
        assert.equal(orderList[0][i],accounts[i+1],"add payorder account test failed");
        assert.equal(orderList[2][i],buyAmount,"add payorder buy amount test failed");
        assert.equal(orderList[3][i],testDeposit,"add payorder account test failed");
        console.log(orderList[0][i],orderList[2][i].toNumber(),orderList[3][i].toNumber());
        testDeposit += TransFee*50;
    }
}
async function sellOptionsToken(tradingInstance,optionsAddr,settlements,SellAmount,account){
    console.log(account);
    let token = await IERC20.at(optionsAddr);
    let balance0 = await token.balanceOf(account);
    await token.approve(tradingInstance.address,SellAmount,{from:account}); 
    let orderList = await tradingInstance.getPayOrderList(optionsAddr,settlements);
    let object0 = {};
    for (var i=0;i<orderList[0].length;i++){
        object0[orderList[0][i]]={
            "buyAmount" : orderList[2][i],
            "deposit" : orderList[3][i],
            "balance" : await token.balanceOf(orderList[0][i])
        };
    }
    await tradingInstance.sellOptionsToken(optionsAddr,SellAmount,collateral0,{from:account});
    let orderList1 = await tradingInstance.getPayOrderList(optionsAddr,settlements);
    let object1 = {};
    for (var i=0;i<orderList1[0].length;i++){
        object1[orderList1[0][i]] = {
            "buyAmount" : orderList1[2][i],
            "deposit" : orderList1[3][i]
        };
    }
    let balance1 = await token.balanceOf(account);
    let balance = balance0.sub(balance1);
    assert.equal(balance.toNumber(),SellAmount,"account options balance test failed");
    for (var i=0;i<orderList[0].length;i++){
        let buyAccount = orderList[0][i];
        let bal = await token.balanceOf(buyAccount);
        let preBal = object0[buyAccount].balance;
        let subBal = bal.sub(preBal).toNumber();
        let sell = object0[buyAccount].buyAmount;
        if(object1[buyAccount]){
            sell = sell.sub(object1[buyAccount].buyAmount).toNumber();
        }else{
            sell = sell.toNumber();
        }
        assert.equal(subBal,sell,"buyOrder owner balance test error");
    }
}
async function addSellOrder(tradingInstance,optionsAddr,settlements,SellAmount,account){
    let token = await IERC20.at(optionsAddr);
    let balance0 = await token.balanceOf(account);
    let balMarket0 = await token.balanceOf(tradingInstance.address);
    await token.approve(tradingInstance.address,SellAmount,{from:account});
    await tradingInstance.addSellOrder(optionsAddr,settlements,SellAmount,{from:account});
    let balance1 = await token.balanceOf(account);
    let balMarket1 = await token.balanceOf(tradingInstance.address);
    let balance = balance0.sub(balance1);
    assert.equal(balance.toNumber(),SellAmount,"account options balance test failed");
    let balMarket = balMarket1.sub(balMarket0);
    assert.equal(balMarket.toNumber(),SellAmount,"market options balance test failed");
}
async function Addcollateral(managerInstance,collateral,priceObj,expiration,optType,amount,account){
    let oracleAddr = await managerInstance.getOracleAddress();
    await functionModule.SetOraclePrice(oracleAddr,priceObj);
    let managerAddress = managerInstance.address;
    let oracleInstance = await TestCompoundOracle.at(oracleAddr);
    let currentPrice = await oracleInstance.getUnderlyingPrice(1);
    let colPrice = await oracleInstance.getPrice(collateral);
    let formulasAddr = await managerInstance.getFormulasAddress();
    let formulasIns = await OptionsFormulas.at(formulasAddr);
    assert(currentPrice>0, "Oracle get underlyingPrice error");
    console.log(currentPrice,colPrice);
    let strikePrice = currentPrice;
    let optionsaddress = await functionModule.OptionsManagerCreateOptionsToken(managerAddress,collateral,1,strikePrice,expiration,optType);
    let CollateralPrice = functionModule.CalCollateralPrice(strikePrice,currentPrice,optType);
    if (optType == 0){
        let getPriceBn = await formulasIns.callCollateralPrice(strikePrice,currentPrice);
        let getPrice = getPriceBn.toNumber();
        assert(Math.abs(CollateralPrice-getPrice)<2,"CollateralPrice calculate error!");
        CollateralPrice = getPrice;
    }else{
        let getPriceBn = await formulasIns.putCollateralPrice(strikePrice,currentPrice);
        let getPrice = getPriceBn.toNumber();
        assert(Math.abs(CollateralPrice-getPrice)<2,"CollateralPrice calculate error!");
        CollateralPrice = getPrice;
    }
    let needMint = Math.floor(colPrice*amount/CollateralPrice);
    console.log(CollateralPrice,needMint);
    let mintAmount = needMint;
    await functionModule.OptionsManagerAddCollateral(managerAddress,optionsaddress,collateral,amount,mintAmount,account);
    return {token:optionsaddress,amount:mintAmount};
}
