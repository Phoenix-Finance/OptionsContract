const functionModule = require ("./testFunctions");
var TestCompoundOracle = artifacts.require("TestCompoundOracle");
var OptionsFormulas = artifacts.require("OptionsFormulas");
let collateral0 = "0x0000000000000000000000000000000000000000";
var IERC20 = artifacts.require("IERC20");
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
    async setOptionsManager(address){
        this.manager = await OptionsManager.at(address);
        let oracleAddr = await this.manager.getOracleAddress();
        this.oracle = await TestCompoundOracle.at(oracleAddr); 
        let formulasAddr = await this.manager.getFormulasAddress();
        this.formulas = await OptionsFormulas.at(formulasAddr);
    }4
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
    async addBuyOrder(optionsAddr,settlements,deposit,buyAmount,account){
        if (settlements == collateral0){
            let txResult =  await this.trading.addPayOrder(optionsAddr,settlements,deposit,buyAmount,{from:account,value:deposit});
            return [txResult];
        }else{
            let token = await IERC20.at(settlements);
            let result1 = await token.approve(this.trading.address,deposit,{from:account});
            let txResult = await this.trading.addPayOrder(optionsAddr,settlements,deposit,buyAmount,{from:account});
            return [result1,txResult];
        }
    }
    async addSellOrder(optionsAddr,settlements,SellAmount,account){
        let token = await IERC20.at(optionsAddr);
        let result1 = await token.approve(this.trading.address,SellAmount,{from:account});
        let txResult = await this.trading.addSellOrder(optionsAddr,settlements,SellAmount,{from:account});
        return [result1,txResult];
    }
    async calSellOptionsToken(optionsAddr,buyAmount,settlements){
        let tokenPrice = await this.oracle.getSellOptionsPrice(optionsAddr);
        let currentPrice = await this.oracle.getPrice(settlements);
        let payfor = Math.floor(tokenPrice*buyAmount/currentPrice);
        let fee = Math.floor(payfor*0.003);
        return[payfor+fee,fee*2,payfor-fee];
    }
    async calBuyOptionsToken(optionsAddr,buyAmount,settlements){
        let tokenPrice = await this.oracle.getBuyOptionsPrice(optionsAddr);
        let currentPrice = await this.oracle.getPrice(settlements);
        let payfor = Math.floor(tokenPrice*buyAmount/currentPrice);
        let fee = Math.floor(payfor*0.003);
        return[payfor+fee,fee*2,payfor-fee];
    }
    async buyOptionsToken(optionsAddr,buyAmount,settlements,settleAmount,account){
        if (settlements == collateral0){
            let txResult =  await this.trading.buyOptionsToken(optionsAddr,buyAmount,settlements,settleAmount,{from:account,value:settleAmount});
            return [txResult];
        }else{
            let token = await IERC20.at(settlements);
            let result1 = await token.approve(this.trading.address,settleAmount,{from:account});
            let txResult = await this.trading.buyOptionsToken(optionsAddr,buyAmount,settlements,settleAmount,{from:account});
            return [result1,txResult];
        }
    }
    async sellOptionsToken(optionsAddr,sellAmount,settlements,account){
        let token = await IERC20.at(optionsAddr);
        let result1 = await token.approve(this.trading.address,sellAmount,{from:account});
        let txResult =  await this.trading.sellOptionsToken(optionsAddr,sellAmount,settlements,{from:account});
        return [result1,txResult];
    }

    async addCollateral(tokenAddress,collateralAmount,mintAmount,account){
        let optionObj = await this.getTokenInfo(tokenAddress);
        return await functionModule.OptionsManagerAddCollateral(this.manager.address,tokenAddress,optionObj.collateral,collateralAmount,mintAmount,account);
    }
    async withdrawCollateral(collateral,amount,account){
        let result = await this.manager.withdrawCollateral(collateral,amount,{from:account});
        return [result];
    }
    async burnOptionsToken(tokenAddress,amount,account){
        let token = await IERC20.at(tokenAddress);
        let result1 = await token.approve(this.manager.address,amount,{from:account});
        let result = await this.manager.burnOptionsToken(tokenAddress,amount,{from:account});
        return [result1,result];
    }
    async getTestStrikePriceList(underlyingAsset,optType){
        let currentPrice = await this.oracle.getUnderlyingPrice(underlyingAsset);
        console.log(currentPrice);
        return functionModule.getTestStrikePrice(currentPrice,optType);
    }
    async calCollateralToMintAmount(tokenAddress,collateralAmount){
        let optionObj = await this.getTokenInfo(tokenAddress);
        let currentPrice = await this.oracle.getUnderlyingPrice(optionObj.underlying);
        let colPrice = await this.oracle.getPrice(optionObj.collateral);
        let collateralPrice = functionModule.CalCollateralPrice(optionObj.strikePrice,currentPrice,optionObj.optType);
//        console.log("+++++++++++++++++++++++++++++++++",currentPrice.toNumber(),colPrice.toNumber(),collateralPrice,optionObj.strikePrice,collateralAmount);
        if (optionObj.optType == 0){
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
        if(payback > colleteralAmount){
            transFee = Math.floor(colleteralAmount*0.003);
            payback = colleteralAmount - transFee;
        }else{
            payback = payback - transFee;
        }
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