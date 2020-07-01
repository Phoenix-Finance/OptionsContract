const BN = require("bn.js");

var TestCompoundOracle = artifacts.require("CompoundOracle");
var OptionsManager = artifacts.require("OptionsManager");
var OptionsFormulas = artifacts.require("OptionsFormulas");
let managerAddress = "0xdA7f569e61943bE22cf060d96F2E081D163c71a6";
let oracleAddr = "0xD0E3971a6E1bea6ee8C08F2Cf0f88cD84C9efC48";
let FormulasAddr = "0xcc64A37d48858b69dE2D64722599E61C5f0aAC9d";
let trading = "0x6A37e518fe45AE1387De13749f635cFa8bE8Cc5d"
let collateral0 = "0x0000000000000000000000000000000000000000";
let MatchMakingTrading = artifacts.require("MatchMakingTrading");
contract('MatchMakingTrading', function (accounts){
    it('ADD NEW  MatchMakingTrading adding buy and sell order', async function (){
        await web3.eth.sendTransaction({from:accounts[7], to: accounts[0],value:50*1e18})
        await web3.eth.sendTransaction({from:accounts[6], to: accounts[0],value:50*1e18})
        await web3.eth.sendTransaction({from:accounts[5], to: accounts[0],value:50*1e18})
        await web3.eth.sendTransaction({from:accounts[4], to: accounts[0],value:50*1e18})
        await web3.eth.sendTransaction({from:accounts[3], to: accounts[0],value:50*1e18})
        await testCollateral();
    })
})
      // --- test add collateral address
async function testCollateral(){
    let managerInstance = await OptionsManager.at(managerAddress);
    let oracleInstance = await TestCompoundOracle.at(oracleAddr);
    let options = await managerInstance.getOptionsTokenList();
    console.log(options);
    let tradingInstance = await MatchMakingTrading.at(trading);
    let Formulas = await OptionsFormulas.at(FormulasAddr);
    let amount = new BN("50000000000000000000",10);
    for (var i=0;i<options.length;i++){
        let needMint = await CollateralToMintAmount(managerInstance,oracleInstance,
            Formulas,options[i],amount)-100000;
        let txResult = await managerInstance.addCollateral(options[i],
            collateral0,amount,new BN(needMint.toString(16),16),{value:amount,gasLimit:4750000});
        console.log(needMint,txResult);
        let sell = Math.floor(needMint/5);
        await addSellOrder(tradingInstance,options[i],collateral0,sell);
        await addSellOrder(tradingInstance,options[i],collateral0,sell);
        await addSellOrder(tradingInstance,options[i],collateral0,sell);
        await addSellOrder(tradingInstance,options[i],collateral0,sell);
        await addSellOrder(tradingInstance,options[i],collateral0,sell);
    }
}
async function addSellOrder(tradingInstance,optionsAddr,settlements,SellAmount){
    let token = await IERC20.at(optionsAddr);
    await token.approve(tradingInstance.address,SellAmount);
    await tradingInstance.addSellOrder(optionsAddr,settlements,SellAmount);
}
async function getTokenInfo(managerInstance,tokenAddress){
    let optionInfo = await managerInstance.getOptionsTokenInfo(tokenAddress);  
    let obj = {
        address : tokenAddress,
        collateral : optionInfo[1],
        underlying : optionInfo[2],
        strikePrice : optionInfo[3].toNumber(),
        expiration : optionInfo[4].toNumber(),
        optType : optionInfo[0],
        isExercised : optionInfo[5],
    }
    console.log(obj);
    return obj;
}
async function CollateralToMintAmount(managerInstance,oracleInstance,Formulas,tokenAddress,collateralAmount){
    let optionObj = await getTokenInfo(managerInstance,tokenAddress);
    let currentPrice = await oracleInstance.getUnderlyingPrice(optionObj.underlying);
    let colPrice = await oracleInstance.getPrice(optionObj.collateral);
    console.log("+++++++++",currentPrice,colPrice);
    let collateralPrice = CalCollateralPrice(optionObj.strikePrice,currentPrice,optionObj.optType);
    let needMint = Math.floor(colPrice*collateralAmount/collateralPrice);
    console.log("------------------------",needMint);
    return needMint;
}
function CalCollateralPrice(strikePrice , currentPrice, optType){
    if (optType == 0){
        return CalCallCollateral(strikePrice,currentPrice);
    }else{
        return CalPutCollateral(strikePrice,currentPrice);
    }
}
function CalCallCollateral(stickPrice , currentPrice){
    if(currentPrice<stickPrice*0.9){
        return _calCallLowerSegment(stickPrice,currentPrice);
    }else if (currentPrice<stickPrice*1.3){
        return _calCallMidSegment(stickPrice,currentPrice);
    }else {
        return _calCallUpperSegment(stickPrice,currentPrice);
    }
}
function CalPutCollateral(stickPrice , currentPrice){
    if(currentPrice<stickPrice*0.7){
        return _calPutLowerSegment(stickPrice,currentPrice);
    }else if (currentPrice<stickPrice*1.1){
        return _calPutMidSegment(stickPrice,currentPrice);
    }else {
        return _calPutUpperSegment(stickPrice,currentPrice);
    }
}

function _calCallLowerSegment(stickPrice , currentPrice){
    var result = currentPrice*5/9;
    var minValue = stickPrice/100;
    if (result<minValue){
        result = minValue;
    }
    return Math.floor(result);
}
function _calCallMidSegment(stickPrice , currentPrice){
    var result = stickPrice/2;
    return Math.floor(result);
}
function _calCallUpperSegment(stickPrice , currentPrice){
    var result = currentPrice - Math.floor(stickPrice*8/10);
    return Math.floor(result);
}

function _calPutLowerSegment(stickPrice , currentPrice){
    var result = -currentPrice+Math.floor(stickPrice*12/10);
     return result;
}
function _calPutMidSegment(stickPrice , currentPrice){
    var result = stickPrice/2;
    return Math.floor(result);
}
function _calPutUpperSegment(stickPrice , currentPrice){
    var result = Math.floor(10*stickPrice/9)- Math.floor(currentPrice*5/9);
    var minValue = stickPrice/100;
    if (result<minValue){
        result = minValue;
    }
    return Math.floor(result);
}