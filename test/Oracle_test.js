var TestCompoundOracle = artifacts.require("TestCompoundOracle");

contract('TestCompoundOracle', function (accounts){
      // --- test add collateral address
  it('Oracle test', function (){
    var oracleInstance;
    return TestCompoundOracle.deployed().then(async function (instance){
            oracleInstance = instance;
            var price = await oracleInstance.getPrice("0x0000000000000000000000000000000000000000");
            assert.equal(price,50,"getPrice failed");
            price = await oracleInstance.getUnderlyingPrice("0x0000000000000000000000000000000000000000");
            assert.equal(price,200,"getUnderlyingPrice failed");
            price = await oracleInstance.getOptionsPrice("0x0000000000000000000000000000000000000000");
            assert.equal(price,100,"getOptionsPrice failed");
            price = await oracleInstance.getSellOptionsPrice("0x0000000000000000000000000000000000000000");
            assert.equal(price,90,"getSellOptionsPrice failed");
            price = await oracleInstance.getBuyOptionsPrice("0x0000000000000000000000000000000000000000");
            assert.equal(price,110,"getBuyOptionsPrice failed");
        });
    });
});