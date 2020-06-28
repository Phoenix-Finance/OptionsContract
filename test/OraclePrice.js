var TestCompoundOracle = artifacts.require("TestCompoundOracle");
var OptionsManager = artifacts.require("OptionsManager");
let managerAddress = "0x2AA0A8510BB82dAD008892FC7C781e2A5FE1741D";
let oracleAddr = "0x54A7CfAf4Fd2b39E790773c0792Eaa689a3f47A2"
contract('TestCompoundOracle', function (accounts){
      // --- test add collateral address
  it('Oracle test', async function (){
        let oracleInstance = await TestCompoundOracle.at(oracleAddr);
        var price = await oracleInstance.getPrice("0x0000000000000000000000000000000000000000");
        console.log(price.toNumber());
        price = await oracleInstance.getPrice("0xc1dfA2Ab731b47968bcD31a57851E0d96aa23229");
        console.log(price.toNumber());
        price = await oracleInstance.getUnderlyingPrice(1);
        console.log(price.toNumber());
        let managerInstance = await OptionsManager.at(managerAddress);
        let options = await managerInstance.getOptionsTokenList();
        console.log(options);
        for (var i=0;i<options.length;i++){
            price = await oracleInstance.getSellOptionsPrice(options[i]);
            console.log(price.toNumber());
            price = await oracleInstance.getBuyOptionsPrice(options[i]);
            console.log(price.toNumber());
        }
    });
});