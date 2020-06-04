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
                price:2116,
            }],
            underlyingAssets:[{
                id:1,
                price:94933900,
            }]
        }
        let expiration = 36000;
        let amount = 10000000000;
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
        let sellAmount = Math.floor(result.amount/2);
        console.log(sellAmount);
        await addSellOrder(tradingInstance,result.token,collateral0,sellAmount,accounts[2]);
        await addPayOrder(tradingInstance,result.token,collateral0,sellAmount,accounts[3]);
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
        let fee0 = await tradingInstance.getFeeBalance(collateral0);
        await sellOptionsToken(tradingInstance,result.token,collateral0,amount,accounts[9]);
        let orderList = await tradingInstance.getPayOrderList(result.token,collateral0);
        for (var i=0;i<orderList[0].length;i++){
            console.log(orderList[0][i],orderList[2][i].toNumber(),orderList[3][i].toNumber());
        }
        let fee1 = await tradingInstance.getFeeBalance(collateral0);
        let fee = fee1.sub(fee0);
        let collateralPrice = await oracleInstance.getPrice(collateral0);
        let calFee = Math.floor(sellPrice*amount/collateralPrice);
        calFee = Math.floor(calFee*0.003)*2;
        console.log(fee.toNumber(),calFee);
        assert(Math.abs(fee.toNumber()-calFee)<10,"Manager Fee test failed");
        await redeemPayOrder(tradingInstance,result.token,collateral0,accounts);
    });
    it('MatchMakingTrading buy options token', async function (){
        let underlyingPrice = 1000000;
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
        let managerIns = await OptionsManager.at(managerAddress);
        await tradingInstance.addWhiteList(collateral0);
        let oracleAddr = await managerIns.getOracleAddress();
        await functionModule.SetOraclePrice(oracleAddr,priceObj);
        let strikePrice = underlyingPrice+underlyingPrice/10;
        let optionsaddress = await functionModule.OptionsManagerCreateOptionsToken(managerAddress,collateral0,1,strikePrice,expiration,0);
        let oracleInstance = await TestCompoundOracle.at(oracleAddr); 
        await oracleInstance.setSellOptionsPrice(optionsaddress,sellPrice);
        await oracleInstance.setBuyOptionsPrice(optionsaddress,buyPrice);
        await addMultiSellOrder(tradingInstance,optionsaddress,expiration,collateral0,amount/4+1000,accounts);
        let fee0 = await tradingInstance.getFeeBalance(collateral0);
        await buyOptionsToken(tradingInstance,optionsaddress,collateral0,amount,accounts[9]);
        let fee1 = await tradingInstance.getFeeBalance(collateral0);
        let fee = fee1.sub(fee0);
        let collateralPrice = await oracleInstance.getPrice(collateral0);
        let calFee = Math.floor(buyPrice*amount/collateralPrice);
        calFee = Math.floor(calFee*0.003)*2;
        console.log(fee.toNumber(),calFee);
        assert(Math.abs(fee.toNumber()-calFee)<10,"Manager Fee test failed");
        await redeemSellOrder(tradingInstance,optionsaddress,collateral0,accounts);
    });
    it('MatchMakingTrading returnExpiredOrders test', async function (){
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
        let expiration = 18000+60;
        let expiration1 = 36000;
        let amount = 1000000000;
        let sellPrice = 990000;
        let buyPrice = 1010000;
        var tradingInstance = await functionModule.migrateMatchMakingTrading();
        let managerAddress = await tradingInstance.getOptionsManagerAddress();
        console.log(managerAddress);
        let managerIns = await OptionsManager.at(managerAddress);
        await tradingInstance.addWhiteList(collateral0);
        let result = await Addcollateral(managerIns,collateral0,priceObj,expiration,0,amount,accounts[9]);
        let result1 = await Addcollateral(managerIns,collateral0,priceObj,expiration1,0,amount,accounts[9]);
        let oracleAddr = await managerIns.getOracleAddress();
        let oracleInstance = await TestCompoundOracle.at(oracleAddr); 
        await oracleInstance.setSellOptionsPrice(result.token,sellPrice);
        await oracleInstance.setBuyOptionsPrice(result.token,buyPrice);
        await oracleInstance.setSellOptionsPrice(result1.token,sellPrice);
        await oracleInstance.setBuyOptionsPrice(result1.token,buyPrice);
        await addMultiPayOrder(tradingInstance,result.token,collateral0,amount/4+1000,accounts);
        await addMultiPayOrder(tradingInstance,result1.token,collateral0,amount/4+1000,accounts);
        await addMultiSellOrder(tradingInstance,result.token,expiration,collateral0,amount/4+1000,accounts);
        await addMultiSellOrder(tradingInstance,result1.token,expiration,collateral0,amount/4+1000,accounts);
        let sellList = await tradingInstance.getSellOrderList(result.token,collateral0);
        let payList = await tradingInstance.getPayOrderList(result.token,collateral0);
        let object1 = {};
        let token = await IERC20.at(result.token);
        for (var i=0;i<6;i++){
            let account = accounts[i+1];
            console.log(sellList[2][i].toNumber(),payList[3][i].toNumber());
            object1[account] = {
                "sellToken":sellList[2][i].toNumber(),
                "settle":payList[3][i].toNumber(),
                "token": await token.balanceOf(account),
                "balance": await web3.eth.getBalance(account),
            }
            console.log(object1[account].token.toNumber(),object1[account].balance);
        }
        await functionModule.sleep(60000);
        await tradingInstance.returnExpiredOrders({from:accounts[9]});
        let sellList1 = await tradingInstance.getSellOrderList(result.token,collateral0);
        let payList1 = await tradingInstance.getPayOrderList(result.token,collateral0);
        assert.equal(sellList1[0].length,0,"returnExpiredOrders test failed");
        assert.equal(payList1[0].length,0,"returnExpiredOrders test failed");
        for (var i=0;i<6;i++){
            let account = accounts[i+1];
            let tokenBal = await token.balanceOf(account);
            console.log(tokenBal.toNumber());
            let trans = tokenBal.sub(object1[account].token).toNumber();
            assert.equal(trans,object1[account].sellToken,"returnExpiredOrders token balance test failed");
            let bal = await web3.eth.getBalance(account);
            assert(Math.abs(bal-object1[account].balance-object1[account].settle)<1000000);
        }
        let sellList2 = await tradingInstance.getSellOrderList(result1.token,collateral0);
        let payList2 = await tradingInstance.getPayOrderList(result1.token,collateral0);
        console.log(sellList2);
        assert.equal(sellList2[0].length,6,"returnExpiredOrders test failed");
        assert.equal(payList2[0].length,6,"returnExpiredOrders test failed");
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
async function redeemPayOrder(tradingInstance,optionsAddr,settlements,accounts){
    for (var i=0;i<6;i++){
        let account = accounts[i+1];
        await tradingInstance.redeemPayOrder(optionsAddr,settlements,{from:account});
     }
     let orderList1 = await tradingInstance.getPayOrderList(optionsAddr,settlements);
     assert.equal(orderList1[0].length,0,"redeemPayOrder empty orderList test failed");
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
async function addMultiSellOrder(tradingInstance,optionsAddr,expiration,settlements,sellAmount,accounts){
    let managerAddress = await tradingInstance.getOptionsManagerAddress();
    let managerIns = await OptionsManager.at(managerAddress);    
    let token = await IERC20.at(optionsAddr);
    let mintAmount = 0;
    let orderListPre = await tradingInstance.getSellOrderList(optionsAddr,settlements);
    for (var i=0;i<6;i++){
        let result = await Addcollateral(managerIns,collateral0,null,expiration,0,sellAmount,accounts[i+1],optionsAddr);
        await token.approve(tradingInstance.address,result.amount,{from:accounts[i+1]});
        mintAmount = result.amount;
        await tradingInstance.addSellOrder(optionsAddr,settlements,result.amount,{from:accounts[i+1]});
    }
    let orderList = await tradingInstance.getSellOrderList(optionsAddr,settlements);
    assert.equal(orderList[0].length,6,"add payorder test failed");
    for (var i=0;i<6;i++){
        assert.equal(orderList[0][i],accounts[i+1],"add payorder account test failed");
        assert.equal(orderList[2][i],mintAmount,"add payorder buy amount test failed");
        console.log(orderList[0][i],orderList[2][i].toNumber());
    }
}
async function buyOptionsToken(tradingInstance,optionsAddr,settlements,buyAmount,account){
    let token = await IERC20.at(optionsAddr);
    let balance0 = await token.balanceOf(account);
    let orderList = await tradingInstance.getSellOrderList(optionsAddr,settlements);
    let object0 = {};
    for (var i=0;i<orderList[0].length;i++){
        console.log(i,orderList[0][i],orderList[2][i].toNumber());
        object0[orderList[0][i]]=orderList[2][i];
    }
    let oracleAddr = await tradingInstance.getOracleAddress();
    let oracleInstance = await TestCompoundOracle.at(oracleAddr);  
    let buyPrice = await oracleInstance.getBuyOptionsPrice(optionsAddr);
    let price = await oracleInstance.getPrice(settlements);
    console.log(buyPrice.toNumber(),price.toNumber());
    let deposit = Math.floor(buyPrice.toNumber()*buyAmount/price.toNumber());
    let feeRate = 0.003;
    let TransFee = Math.floor(deposit*feeRate);
    let currencyAmount = deposit;
    let buyError = false;
    try {
        await tradingInstance.buyOptionsToken(optionsAddr,buyAmount,collateral0,currencyAmount,{from:account,value:currencyAmount});
    } catch (error) {
        buyError = true;        
    }
    assert(buyError, "settlements currency insufficient test fail!");
    currencyAmount+=TransFee;
    await tradingInstance.buyOptionsToken(optionsAddr,buyAmount,collateral0,currencyAmount,{from:account,value:currencyAmount});
    let orderList1 = await tradingInstance.getSellOrderList(optionsAddr,settlements);
    console.log("------------------------------------------");
    let object1 = {};
    for (var i=0;i<orderList1[0].length;i++){
        console.log(i,orderList1[0][i],orderList1[2][i].toNumber());
        object1[orderList1[0][i]] = orderList1[2][i];
    }
    let balance1 = await token.balanceOf(account);
    let balance = balance1.sub(balance0);
    console.log(balance0.toNumber(),balance1.toNumber());
    assert.equal(balance.toNumber(),buyAmount,"account options balance test failed");
}
async function redeemSellOrder(tradingInstance,optionsAddr,settlements,accounts){
    let token = await IERC20.at(optionsAddr);
    let orderList1 = await tradingInstance.getSellOrderList(optionsAddr,settlements);
    let object1 = {};
    for (var i=0;i<orderList1[0].length;i++){
        object1[orderList1[0][i]] = orderList1[2][i].toNumber();
    }
    for (var i=0;i<6;i++){
        let account = accounts[i+1];
        let balance0 = await token.balanceOf(account);
        await tradingInstance.redeemSellOrder(optionsAddr,settlements,{from:account});
        let balance1 = await token.balanceOf(account);
        let balSub = balance1.sub(balance0).toNumber();
        if (object1[account]){
            assert.equal(balSub,object1[account],"account options balance test failed");
        }else{
            assert.equal(balSub,0,"account options balance test failed");
        }
     }
     orderList1 = await tradingInstance.getSellOrderList(optionsAddr,settlements);
     assert.equal(orderList1[0].length,0,"redeemSellOrder empty orderList test failed");
}
async function Addcollateral(managerInstance,collateral,priceObj,expiration,optType,amount,account,optionsaddress){
    let oracleAddr = await managerInstance.getOracleAddress();
    if (priceObj){
        await functionModule.SetOraclePrice(oracleAddr,priceObj);
    }
    let managerAddress = managerInstance.address;
    let oracleInstance = await TestCompoundOracle.at(oracleAddr);
    let currentPrice = await oracleInstance.getUnderlyingPrice(1);
    let colPrice = await oracleInstance.getPrice(collateral);
    let formulasAddr = await managerInstance.getFormulasAddress();
    let formulasIns = await OptionsFormulas.at(formulasAddr);
    assert(currentPrice>0, "Oracle get underlyingPrice error");
    console.log(currentPrice,colPrice);
    let strikePrice = currentPrice;
    if (!optionsaddress){
        optionsaddress = await functionModule.OptionsManagerCreateOptionsToken(managerAddress,collateral,1,strikePrice,expiration,optType);
    }else {
        let managerIns = await OptionsManager.at(managerAddress); 
        let optionInfo = await managerIns.getOptionsTokenInfo(optionsaddress);  
        strikePrice = optionInfo[3].toNumber();
        console.log(strikePrice);
    }
        
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
