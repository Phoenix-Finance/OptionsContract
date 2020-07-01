const BN = require("bn.js");

var CompoundOracle = artifacts.require("CompoundOracle");
var OptionsManager = artifacts.require("OptionsManager");
let managerAddress = "0xd064d5f14Ef1C06F2080F2d6962d01eB290BcB7b";
let oracleAddr = "0xD23864e996a11269E93983706d3D71099c410595";
let marketAddr = "0x9B3CA30c1Fc25F21dC33d2569Ab33F039fa3aF29";
let MatchMakingTrading = artifacts.require("MatchMakingTrading");
var IERC20 = artifacts.require("IERC20");
contract('TestCompoundOracle', function (accounts){
      // --- test add collateral address
  it('Oracle test', async function (){
   let market = await MatchMakingTrading.at(marketAddr);
   let token = await IERC20.at("0x358A81b74094c0fD4F9129021c9d4DA3Ab479de9");
   amount = new BN("1768561170000000000",10)
   await token.approve(marketAddr,amount);
   await market.buyOptionsToken("0xF825a70661497F613c046892aeac57F2fFA7c803",400000000000000,
            "0x358A81b74094c0fD4F9129021c9d4DA3Ab479de9",amount)
        let oracleInstance = await CompoundOracle.at(oracleAddr);
        let ownerAddr = await oracleInstance.owner();
        console.log(ownerAddr)
        var price = await oracleInstance.getPriceDetail("0x0000000000000000000000000000000000000000");
        console.log(price[0].toString(),price[1].toString());
        price = await oracleInstance.getPriceDetail("0xdF228001e053641FAd2BD84986413Af3BeD03E0B");
        console.log(price[0].toString(),price[1].toString());
        price = await oracleInstance.getUnderlyingPriceDetail(1);
        console.log(price[0].toString(),price[1].toString());
        let managerInstance = await OptionsManager.at(managerAddress);
        let options = await managerInstance.getOptionsTokenList();
        console.log(options);
        for (var i=0;i<options.length;i++){
            price = await oracleInstance.getSellOptionsPriceDetail(options[i]);
            console.log(price[0].toString(),price[1].toString());
            price = await oracleInstance.getBuyOptionsPriceDetail(options[i]);
            console.log(price[0].toString(),price[1].toString());
        }
    });
});