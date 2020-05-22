var OptionsManager = artifacts.require("OptionsManager");

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
});
