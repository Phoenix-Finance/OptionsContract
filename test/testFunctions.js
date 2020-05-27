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
exports.migrateMatchMakingTrading = async function(){
    return MatchMakingTrading.deployed().then(async function (instance){
        let matchInstance = instance;
        console.log("MatchMakingTrading Address : ", instance.address);
        let managerInstance = await exports.migrateOptionsManager();
        await matchInstance.setOptionsManagerAddress(managerInstance.address);
        let oracleAddr = await managerInstance.getOracleAddress();
        await matchInstance.setOracleAddress(oracleAddr);
        return matchInstance;
    });
}
exports.OptionsManagerCreateOptionsToken = async function(managerAddress,collateral,underlyingAssets,strikePrice,expiration,optType){
    let managerInstance = await OptionsManager.at(managerAddress);
    await managerInstance.addWhiteList(collateral);
    await managerInstance.createOptionsToken(collateral,underlyingAssets,strikePrice,3,expiration,optType);
    let options = await managerInstance.getOptionsTokenList();
    let value = await managerInstance.getOptionsTokenInfo(options[options.length-1]);
    console.log(value[3].toNumber());
    return options[options.length-1];
}
exports.OptionsManagerGetFirstOptionsToken = async function(managerAddress,collateral,underlyingAssets,strikePrice,expiration,optType){
    let managerInstance = await OptionsManager.at(managerAddress);
    let options = await managerInstance.getOptionsTokenList();
    if (!options || options.length == 0){
        return await exports.OptionsManagerCreateOptionsToken(managerAddress,collateral,underlyingAssets,strikePrice,expiration,optType);
    }else{
        let value = await managerInstance.getOptionsTokenInfo(options[options.length-1]);
        console.log(value[3].toNumber());
        return options[0];
    }
}
exports.OptionsManagerAddCollateral = async function(managerAddress,tokenAddress,collateral,amount,mintOptionsTokenAmount,account){
    let managerInstance = await OptionsManager.at(managerAddress);
    if (collateral == "0x0000000000000000000000000000000000000000"){
        await managerInstance.addCollateral(tokenAddress,collateral,amount,mintOptionsTokenAmount,{from:account,value:amount});
    }else{
        let token = await IERC20.at(collateral);
        await token.approve(managerAddress,amount,{from:account});
        await managerInstance.addCollateral(tokenAddress,collateral,amount,mintOptionsTokenAmount,{from:account});
    }
}



