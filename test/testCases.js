const functionModule = require ("./testFunctions");
var TestCompoundOracle = artifacts.require("TestCompoundOracle");
var OptionsFormulas = artifacts.require("OptionsFormulas");
module.exports =  class {
    constructor(){
        this.tokenMap = {};
    }
    async setOraclePrice(priceObj){
        if (priceObj.PriceList){
            for (var i=0;i<priceObj.PriceList.length;i++)
                await this.oracle.setPrice(priceObj.PriceList[i].address,priceObj.PriceList[i].price);
        }
        if (priceObj.underlyingAssets){
            for (var i=0;i<priceObj.underlyingAssets.length;i++)
                await this.oracle.setUnderlyingPrice(priceObj.underlyingAssets[i].id,priceObj.underlyingAssets[i].price);
        }
        if (priceObj.SellList){
            for (var i=0;i<priceObj.SellList.length;i++)
                await this.oracle.setSellOptionsPrice(priceObj.SellList[i].address,priceObj.SellList[i].price);
        }
        if (priceObj.BuyList){
            for (var i=0;i<priceObj.BuyList.length;i++)
                await this.oracle.setBuyOptionsPrice(priceObj.BuyList[i].address,priceObj.BuyList[i].price);
        }
    }
    async migrateOptionsManager(){
        this.manager = await functionModule.migrateOptionsManager();
        let oracleAddr = await this.manager.getOracleAddress();
        this.oracle = await TestCompoundOracle.at(oracleAddr); 
        let formulasAddr = await this.manager.getFormulasAddress();
        this.formulas = await OptionsFormulas.at(formulasAddr);
    }
    async migrateMatchMakingTrading(){
        if (!this.manager){
            migrateOptionsManager();
        }
        this.trading = await functionModule.migrateMatchMakingTrading(this.manager);
    }
    async getStrikePrice(underlyingAssets,trikeRate){
        let currentPrice = await this.oracle.getUnderlyingPrice(underlyingAssets);
        return Math.floor(currentPrice*trikeRate);
    }
    async createOptionsToken(collateral,underlyingAssets,expiration,optType,strikePrice,checkbalance){
        let addr = await functionModule.OptionsManagerCreateOptionsToken(this.manager.address,collateral,underlyingAssets,strikePrice,expiration,optType,checkbalance);
        let obj = {
            address : addr,
            collateral : collateral,
            underlying : underlyingAssets,
            strikePrice : strikePrice,
            expiration : expiration,
            optType : optType,
            isExercised: false,
        }
        return obj;
    }
    async addCollateral(tokenAddress,collateralAmount,mintAmount,account){
        let optionObj = await this.getTokenInfo(tokenAddress);
        return await functionModule.OptionsManagerAddCollateral(this.manager.address,tokenAddress,optionObj.collateral,collateralAmount,mintAmount,account);
    }
    async getTestStrikePriceList(underlyingAsset,optType){
        let currentPrice = await this.oracle.getUnderlyingPrice(underlyingAsset);
        console.log(currentPrice);
        return functionModule.getTestStrikePrice(currentPrice,optType);
    }
    async calCollateralToMintAmount(tokenAddress,collateralAmount,optType){
        let optionObj = await this.getTokenInfo(tokenAddress);
        let currentPrice = await this.oracle.getUnderlyingPrice(optionObj.underlying);
        let colPrice = await this.oracle.getPrice(optionObj.collateral);
        let collateralPrice = functionModule.CalCollateralPrice(optionObj.strikePrice,currentPrice,optType);
//        console.log("+++++++++++++++++++++++++++++++++",currentPrice.toNumber(),colPrice.toNumber(),collateralPrice,optionObj.strikePrice,collateralAmount);
        if (optType == 0){
            let getPriceBn = await this.formulas.callCollateralPrice(optionObj.strikePrice,currentPrice);
            let getPrice = getPriceBn.toNumber();
            assert(Math.abs(collateralPrice-getPrice)<2,"CollateralPrice calculate error!");
            collateralPrice = getPrice;
        }else{
            let getPriceBn = await this.formulas.putCollateralPrice(optionObj.strikePrice,currentPrice);
            let getPrice = getPriceBn.toNumber();
            assert(Math.abs(collateralPrice-getPrice)<2,"CollateralPrice calculate error!");
            collateralPrice = getPrice;
        }
        let needMint = Math.floor(colPrice*collateralAmount/collateralPrice);
        return needMint;
    }
    async calLiquidatePayback(optionsToken,amount,collateral,colleteralAmount){
        let tokenPrice = await this.oracle.getBuyOptionsPrice(optionsToken);
        let payback = tokenPrice*amount;
        let price = await this.oracle.getPrice(collateral);
        payback = Math.floor(payback/price);
        let incentiveRate = await this.manager.getLiquidationIncentive();
        let incentive = payback*incentiveRate[0].toNumber();
        incentive = Math.floor(incentive*Math.pow(10,incentiveRate[1].toNumber()));
        payback = payback+incentive;
        let transFee = Math.floor(payback*0.003);
        let bothPay = payback+transFee;
        if(bothPay > colleteralAmount){
            transFee = Math.floor(colleteralAmount*0.003);
            payback = colleteralAmount - transFee;
        }
        console.log(payback,colleteralAmount);
        return payback;
    }
    async getTokenInfo(tokenAddress){
        let optionInfo = await this.manager.getOptionsTokenInfo(tokenAddress);  
        let obj = {
            address : tokenAddress,
            collateral : optionInfo[1],
            underlying : optionInfo[2],
            strikePrice : optionInfo[3].toNumber(),
            expiration : optionInfo[4].toNumber(),
            optType : optionInfo[0],
            isExercised : optionInfo[5],
        }
        return obj;
    }
}