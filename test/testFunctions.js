var OptionsManager = artifacts.require("OptionsManager");
var TestCompoundOracle = artifacts.require("TestCompoundOracle");
var OptionsFormulas = artifacts.require("OptionsFormulas");
var OptionsToken = artifacts.require("OptionsToken");
let MatchMakingTrading = artifacts.require("MatchMakingTrading");
var IERC20 = artifacts.require("IERC20");
exports.migrateOptionsManager = async function(){
    let managerInstance;
    let oracleInstance;
    let formulasInstance;
    return OptionsManager.deployed().then(function (instance){
        managerInstance = instance;
        console.log("OptionsManager Address : ", instance.address);
        return TestCompoundOracle.deployed();
    }).then(function(instance){
        oracleInstance = instance;
        console.log("TestCompoundOracle Address : ", instance.address);
        return OptionsFormulas.deployed();
    }).then(async function(instance){
        console.log("OptionsFormulas Address : ", instance.address);
        formulasInstance = instance;
        await managerInstance.setOracleAddress(oracleInstance.address);
        await managerInstance.setFormulasAddress(formulasInstance.address);
        return managerInstance;
    });
}
exports.migrateMatchMakingTrading = async function(managerInstance){
    return MatchMakingTrading.deployed().then(async function (instance){
        let matchInstance = instance;
        console.log("MatchMakingTrading Address : ", instance.address);
        if (!managerInstance){
            managerInstance = await exports.migrateOptionsManager();
        }
        await matchInstance.setOptionsManagerAddress(managerInstance.address);
        let oracleAddr = await managerInstance.getOracleAddress();
        await matchInstance.setOracleAddress(oracleAddr);
        return matchInstance;
    });
}
exports.OptionsManagerCreateOptionsToken = async function(managerAddress,collateral,underlyingAssets,strikePrice,expiration,optType,checkbalance){
    let managerInstance = await OptionsManager.at(managerAddress);
    let result = await managerInstance.addWhiteList(collateral);
    if(checkbalance){
        await checkbalance.setTx(result.tx);
    }
    result = await managerInstance.createOptionsToken("options token 1",collateral,underlyingAssets,strikePrice,expiration,optType);
    if(checkbalance){
        await checkbalance.setTx(result.tx);
    }
    let options = await managerInstance.getOptionsTokenList();
    let value = await managerInstance.getOptionsTokenInfo(options[options.length-1]);
    console.log(options);
    return options[options.length-1];
}
exports.OptionsManagerGetFirstOptionsToken = async function(managerAddress,collateral,underlyingAssets,strikePrice,expiration,optType){
    let managerInstance = await OptionsManager.at(managerAddress);
    let options = await managerInstance.getOptionsTokenList();
    if (!options || options.length == 0){
        return await exports.OptionsManagerCreateOptionsToken(managerAddress,collateral,underlyingAssets,strikePrice,expiration,optType);
    }else{
        let value = await managerInstance.getOptionsTokenInfo(options[options.length-1]);
        console.log(value[4].toNumber());
        return options[0];
    }
}
exports.OptionsManagerAddCollateral = async function(managerAddress,tokenAddress,collateral,amount,mintOptionsTokenAmount,account){
    let managerInstance = await OptionsManager.at(managerAddress);
    if (collateral == "0x0000000000000000000000000000000000000000"){
        let txResult = await managerInstance.addCollateral(tokenAddress,collateral,amount,mintOptionsTokenAmount,{from:account,value:amount});
        return txResult;
    }else{
        let token = await IERC20.at(collateral);
        await token.approve(managerAddress,amount,{from:account});
        let txResult = await managerInstance.addCollateral(tokenAddress,collateral,amount,mintOptionsTokenAmount,{from:account});
        return txResult;
    }
}
exports.SetOraclePrice = async function (oracleAddr,priceObj) {
    let oracleInstance = await TestCompoundOracle.at(oracleAddr);
    if (priceObj.PriceList){
        for (var i=0;i<priceObj.PriceList.length;i++)
            await oracleInstance.setPrice(priceObj.PriceList[i].address,priceObj.PriceList[i].price);
    }
    if (priceObj.underlyingAssets){
        for (var i=0;i<priceObj.underlyingAssets.length;i++)
            await oracleInstance.setUnderlyingPrice(priceObj.underlyingAssets[i].id,priceObj.underlyingAssets[i].price);
    }
    if (priceObj.SellList){
        for (var i=0;i<priceObj.SellList.length;i++)
            await oracleInstance.setSellOptionsPrice(priceObj.SellList[i].address,priceObj.SellList[i].price);
    }
    if (priceObj.BuyList){
        for (var i=0;i<priceObj.BuyList.length;i++)
            await oracleInstance.setBuyOptionsPrice(priceObj.BuyList[i].address,priceObj.BuyList[i].price);
    }

}
exports.CalCollateralPrice = function(strikePrice , currentPrice, optType){
    if (optType == 0){
        return CalCallCollateral(strikePrice,currentPrice);
    }else{
        return CalPutCollateral(strikePrice,currentPrice);
    }
}
exports.getTestStrikePrice = function(currentPrice,optType) {
    if (optType == 0){
        return [Math.floor(currentPrice*2),Math.floor(currentPrice*1.05/0.9),Math.floor(currentPrice*1.05/1.3),Math.floor(currentPrice*0.9/1.3),Math.floor(currentPrice*0.3)];
    }else{
        return [Math.floor(currentPrice*2),Math.floor(currentPrice*1.05/0.7),Math.floor(currentPrice*1.05/1.1),Math.floor(currentPrice*0.9/1.1),Math.floor(currentPrice*0.3)];
    }
}
exports.sleep = function(time) {
    return new Promise((resolve, reject) => {
      setTimeout(() => {
        resolve();
      }, time);
    });
};
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
