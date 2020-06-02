const functionModule = require ("./testFunctions");
var OptionsManager = artifacts.require("OptionsManager");
var TestCompoundOracle = artifacts.require("TestCompoundOracle");
var IERC20 = artifacts.require("IERC20");
let collateral0 = "0x0000000000000000000000000000000000000000";
let gasPrice = 20000000000;
contract('OptionsManager', function (accounts){
    it('OptionsManager adding Collateral case one', async function (){
        let priceObj = {
            PriceList: [{
                address:collateral0,
                price:100000,
            }],
            underlyingAssets:[{
                id:1,
                price:100000,
            }]
        }
        let expiration = 3600;
        let amount = 1000000000;

        console.log("call options adding collateral!");
        await testAddcollateral(collateral0,priceObj,expiration,0,amount,accounts);
        console.log("put options adding collateral!");
        await testAddcollateral(collateral0,priceObj,expiration,1,amount,accounts);
    });
    it('OptionsManager adding Collateral case two', async function (){
        let priceObj = {
            PriceList: [{
                address:collateral0,
                price:10000,
            }],
            underlyingAssets:[{
                id:1,
                price:1000000,
            }]
        }
        let expiration = 3600;
        let amount = 1000000000;
        console.log("call options adding collateral!");
        await testAddcollateral(collateral0,priceObj,expiration,0,amount,accounts);
        console.log("put options adding collateral!");
        await testAddcollateral(collateral0,priceObj,expiration,1,amount,accounts);
    });
    it('OptionsManager adding Collateral case three', async function (){
        let priceObj = {
            PriceList: [{
                address:collateral0,
                price:10000000,
            }],
            underlyingAssets:[{
                id:1,
                price:100000,
            }]
        }
        let expiration = 3600;
        let amount = 1000000000;
        console.log("call options adding collateral!");
        await testAddcollateral(collateral0,priceObj,expiration,0,amount,accounts);
        console.log("put options adding collateral!");
        await testAddcollateral(collateral0,priceObj,expiration,1,amount,accounts);
    });
});
async function testAddcollateral(collateral,priceObj,expiration,optType,amount,accounts){

    var managerInstance = await functionModule.migrateOptionsManager();
    let oracleAddr = await managerInstance.getOracleAddress();
    await functionModule.SetOraclePrice(oracleAddr,priceObj);
    let managerAddress = managerInstance.address;
    let oracleInstance = await TestCompoundOracle.at(oracleAddr);
    let currentPrice = await oracleInstance.getUnderlyingPrice(1);
    let colPrice = await oracleInstance.getPrice(collateral);
    assert(currentPrice>0, "Oracle get underlyingPrice error");
    console.log(currentPrice,colPrice);
    let strikePrices = functionModule.getTestStrikePrice(currentPrice,optType);
    for (var i = 0;i < strikePrices.length; i++) {
        let strikePrice = strikePrices[i];
        let optionsaddress = await functionModule.OptionsManagerCreateOptionsToken(managerAddress,collateral,1,strikePrice,expiration,optType);
        let CollateralPrice = functionModule.CalCollateralPrice(strikePrice,currentPrice,optType);
        let needMint = Math.floor(colPrice*amount/CollateralPrice);
        console.log(CollateralPrice,needMint);
        let index = 1;
        for (var mintAmount = needMint+10;mintAmount>needMint-15;mintAmount-=10){
            let account = accounts[index];
            index++;
            console.log(i,account,strikePrice,mintAmount);
            if (mintAmount > needMint){
                let txError = false;
                try {
                    let txResult = await functionModule.OptionsManagerAddCollateral(managerAddress,optionsaddress,collateral,amount,mintAmount,account);
                } catch (error) {
                    txError = true;
                }
                assert(txError,"test insufficient collateral failed!");
            }else{
                let balance0 = await web3.eth.getBalance(account);
                let txResult = await functionModule.OptionsManagerAddCollateral(managerAddress,optionsaddress,collateral,amount,mintAmount,account);
                let gasUsed = txResult.receipt.gasUsed*gasPrice;
                let balance1 = await web3.eth.getBalance(account);
                let ethUsed = balance0-balance1;
                assert(Math.abs(ethUsed-amount-gasUsed)<1000000,"AddCollateral balance error");    
            }

        }
    }
}
