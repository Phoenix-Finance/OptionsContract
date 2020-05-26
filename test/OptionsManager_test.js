var OptionsManager = artifacts.require("OptionsManager");
var TestCompoundOracle = artifacts.require("TestCompoundOracle");
var OptionsFormulas = artifacts.require("OptionsFormulas");
var OptionsToken = artifacts.require("OptionsToken");
contract('OptionsManager', function (accounts){

  // --- test add collateral address
  it('add collateral address', function (){
    var managerInstance;
    return OptionsManager.deployed().then(function (instance){
      managerInstance = instance;
      return managerInstance.addWhiteList("0x0000000000000000000000000000000000000000");
    }).then(function(){
        return managerInstance.addWhiteList("0x0000000000000000000000000000000000000000");
    }).then(function(){
      return managerInstance.getWhiteList();
    }).then(function(whiteList){
      assert.equal(whiteList.length,1,"whiteList is empty");
      assert.equal(whiteList[0],"0x0000000000000000000000000000000000000000","whiteList is not zero");
    }).then(function(){
        return managerInstance.addWhiteList("0x0000000000000000000000000000000000000100");
    }).then(function(storedData){
      return managerInstance.getWhiteList();
    }).then(function(whiteList){
      assert.equal(whiteList.length,2,"The second address insert failed");
      assert.equal(whiteList[1],"0x0000000000000000000000000000000000000100","The second address is wrong");
    });
  });
  //test remove collateral address
    it('remove collateral address', function (){
    var managerInstance;
    return OptionsManager.deployed().then(function (instance){
      managerInstance = instance;
      return managerInstance.removeWhiteList("0x0000000000000000000000000000000000000000");
    }).then(function(){
      return managerInstance.getWhiteList();
    }).then(function(whiteList){
      assert.equal(whiteList.length,1,"address is removed error");
      assert(whiteList[0]!="0x0000000000000000000000000000000000000000","whiteList is not zero");
    }).then(function(){
        return managerInstance.isEligibleAddress("0x0000000000000000000000000000000000000000");
    }).then(function(result){
        assert.equal(result,false,"address is removed");
    }).then(function(){
        return managerInstance.isEligibleAddress("0x0000000000000000000000000000000000000100");
    }).then(function(result){
        assert.equal(result,true,"address is eligible address");
    }).then(function(){
        return managerInstance.removeWhiteList("0x0000000000000000000000000000000000000100");
    }).then(function(){
      return managerInstance.getWhiteList();
    }).then(function(whiteList){
      assert.equal(whiteList.length,0,"The second address is removed error");
    }).then(function(){
        return managerInstance.isEligibleAddress("0x0000000000000000000000000000000000000000");
    }).then(function(result){
        assert.equal(result,false,"address is removed");
    }).then(function(){
        return managerInstance.isEligibleAddress("0x0000000000000000000000000000000000000100");
    }).then(function(result){
        assert.equal(result,false,"address is removed");
    });
  });
    // --- test add collateral address sender is not owner
  it('add collateral address,sender is not owner', function (){
    var managerInstance;
    var whiteLength = 0;
    return OptionsManager.deployed().then(function(instance){
        managerInstance = instance;
        return managerInstance.getWhiteList();
    }).then(async function (whiteList){
        whiteLength = whiteList.length;
        let errorThrown = false;
        try {
            await managerInstance.addWhiteList("0x0000000000000000000000000000000000000200",{from:accounts[1]});
        }catch (err) {
            errorThrown = true;
        }
        assert.isTrue(errorThrown);
    }).then(function(){
        return managerInstance.getWhiteList();
    }).then(function(whiteList){
        assert.equal(whiteList.length,whiteLength,"add whiteList is error");
    });
  });
    //test remove collateral address sender is not owner
    it('remove collateral address,sender is not owner', function (){
        var managerInstance;
        var whiteLength = 0;
        return OptionsManager.deployed().then(function(instance){
            managerInstance = instance;
        }).then(function(){
            return managerInstance.addWhiteList("0x0000000000000000000000000000000000000000");
        }).then(function(){
            return managerInstance.addWhiteList("0x0000000000000000000000000000000000000100");
        }).then(function(){
            return managerInstance.getWhiteList();
        }).then(async function (whiteList){
            whiteLength = whiteList.length;
            let errorThrown = false;
            try {
                await managerInstance.removeWhiteList("0x0000000000000000000000000000000000000200",{from:accounts[1]});
            }catch (err) {
                errorThrown = true;
            }
            assert.isTrue(errorThrown);
        }).then(function(){
            return managerInstance.getWhiteList();
        }).then(function(whiteList){
            assert.equal(whiteList.length,whiteLength,"add whiteList is error");
        });
    });
    //test Oracle address and formulas address
    it('set Oracle address and formulas address', function (){
      var managerInstance;
      var OracleInstance;
      var formulasInstance;
      return OptionsManager.deployed().then(function(instance){
          managerInstance = instance;
      }).then(function(){
          return TestCompoundOracle.deployed();
      }).then(function(instance){
          OracleInstance = instance;
          return managerInstance.setOracleAddress(instance.address);
      }).then(function(){
          return OptionsFormulas.deployed();
      }).then(async function (instance){
        formulasInstance = instance;
        return managerInstance.setFormulasAddress(instance.address);
      }).then(async function(){
          let result = await managerInstance.getOracleAddress();
          assert.equal(result,OracleInstance.address, "Oracle address setting Failed");
          result = await managerInstance.getFormulasAddress();
          assert.equal(result,formulasInstance.address,"formulas address setting Failed");
      });
  });
  //create new options token
  it('create new options token', function (){
    var managerInstance;
    var collateralAddress = "0x0000000000000000000000000000000000000000";
    return OptionsManager.deployed().then(function(instance){
        managerInstance = instance;
        return managerInstance.addCollateralCurrency(collateralAddress);
    }).then(async function(){
        let optionsList = await managerInstance.getOptionsTokenList();
        console.log(optionsList);
        var whiteList = await managerInstance.getCollateralList();
        console.log(whiteList);
        await managerInstance.createOptionsToken(whiteList[0],1,200,3,100000,0);
        optionsList = await managerInstance.getOptionsTokenList();
        console.log(optionsList);
        await managerInstance.createOptionsToken(whiteList[1],0,200,3,10000000,0);
        optionsList = await managerInstance.getOptionsTokenList();
        console.log(optionsList);
        let options0 = await managerInstance.getOptionsTokenInfo(optionsList[0]);
        console.log(options0);
        let options1 = await managerInstance.getOptionsTokenInfo(optionsList[1]);
        console.log(options1);
    })  
  });
   //add collateral
   it('add collateral to new options token', function (){
    var managerInstance;
    var collateralAddress = "0x0000000000000000000000000000000000000000";
    return OptionsManager.deployed().then(function(instance){
        managerInstance = instance;
    }).then(async function(){
        let optionsList = await managerInstance.getOptionsTokenList();
        console.log(optionsList);
        /*
        let errorThrown = false;
        try {
              await managerInstance.addCollateral(optionsList[0],collateralAddress,10,40,{from:accounts[1],value:10});
        }
        catch (err) {
            errorThrown = true;
        }
        assert.isTrue(errorThrown);*/
        await managerInstance.addCollateral(optionsList[0],collateralAddress,100,50,{from:accounts[1],value:100});

        let otoken = await OptionsToken.at(optionsList[0]);
        await otoken.increaseAllowance(managerInstance.address,25,{from:accounts[1]});
        await managerInstance.burnOptionsToken(optionsList[0],25,{from:accounts[1]});

        await managerInstance.withdrawCollateral(optionsList[0],50,{from:accounts[1]});
    })  
  });
});
async function FunctionRevertTest(func){
    let errorThrown = false;
    try {
        func();
    }
    catch (err) {
        errorThrown = true;
    }
    assert.isTrue(errorThrown);
}