var OptionsFormulas = artifacts.require("OptionsFormulas");
const functionModule = require ("./testFunctions");
const BN = require('bn.js');

contract('OptionsFormulas', function (accounts){

  it('OptionsFormulas call formulas get', function (){
        var formulasInstance;
        return OptionsFormulas.deployed().then(async function (instance){
            formulasInstance = instance;
            var result = await formulasInstance.getCallLowerDemarcation();
            assert(result[0]==9 && result[1] == -1,"getCallLowerDemarcation failed");
            result = await formulasInstance.getCallUpperDemarcation();
            assert(result[0]==13 && result[1] == -1,"getCallUpperDemarcation failed");
            result = await formulasInstance.getCallLowerLimit();
            assert(result[0]==1 && result[1] == -2,"getCallLowerLimit failed");
            result = await formulasInstance.getCallLowerSegment();
            assert(result[0]==0 && result[1] == 0 && result[2]==5555555556 && result[3] == -10,"getCallLowerSegment failed");
            result = await formulasInstance.getCallMidSegment();
            assert(result[0]==5 && result[1] == -1 && result[2]==0 && result[3] == 0,"getCallMidSegment failed");
            result = await formulasInstance.getCallUpperSegment();
            assert(result[0]==-8 && result[1] == -1 && result[2]==1 && result[3] == 0,"getCallUpperSegment failed");
        });
    });

    it('OptionsFormulas call formulas call', function (){
        var formulasInstance;
        return OptionsFormulas.deployed().then(async function (instance){
            formulasInstance = instance;
            var strickPrice = 100000;
            var currentPrice = strickPrice;
            //mid segment
            var result = await formulasInstance.callCollateralPrice(strickPrice,currentPrice);
            var correct = functionModule.CalCallCollateral(strickPrice,currentPrice);
            assert(result.toNumber() == correct,"callCollateralPrice failed");
            currentPrice = strickPrice*9/10;
            result = await formulasInstance.callCollateralPrice(strickPrice,currentPrice);
            correct = functionModule.CalCallCollateral(strickPrice,currentPrice);
            assert(result.toNumber() == correct,"callCollateralPrice failed");
            currentPrice = strickPrice*13/10;
            result = await formulasInstance.callCollateralPrice(strickPrice,currentPrice);
            correct = functionModule.CalCallCollateral(strickPrice,currentPrice);
            assert(result.toNumber() == correct,"callCollateralPrice failed");
            //lower segment
            currentPrice = strickPrice*5/10;
            result = await formulasInstance.callCollateralPrice(strickPrice,currentPrice);
            correct = functionModule.CalCallCollateral(strickPrice,currentPrice);
            console.log(result.toNumber(),correct);
            assert(result.toNumber() == correct,"callCollateralPrice failed");
            currentPrice = strickPrice*3/10;
            result = await formulasInstance.callCollateralPrice(strickPrice,currentPrice);
            correct = functionModule.CalCallCollateral(strickPrice,currentPrice);
            console.log(result.toNumber(),correct);
            assert(result.toNumber() == correct,"callCollateralPrice failed");
            currentPrice = strickPrice*1/1000;
            result = await formulasInstance.callCollateralPrice(strickPrice,currentPrice);
            correct = functionModule.CalCallCollateral(strickPrice,currentPrice);
            console.log(result.toNumber(),correct);
            assert(result.toNumber() == correct,"callCollateralPrice failed");
            //upper segment
            currentPrice = strickPrice*15/10;
            result = await formulasInstance.callCollateralPrice(strickPrice,currentPrice);
            correct = functionModule.CalCallCollateral(strickPrice,currentPrice);
            console.log(result.toNumber(),correct);
            assert(result.toNumber() == correct,"callCollateralPrice failed");
            currentPrice = strickPrice*2;
            result = await formulasInstance.callCollateralPrice(strickPrice,currentPrice);
            correct = functionModule.CalCallCollateral(strickPrice,currentPrice);
            console.log(result.toNumber(),correct);
            assert(result.toNumber() == correct,"callCollateralPrice failed");
            currentPrice = strickPrice*5;
            result = await formulasInstance.callCollateralPrice(strickPrice,currentPrice);
            correct = functionModule.CalCallCollateral(strickPrice,currentPrice);
            console.log(result.toNumber(),correct);
            assert(result.toNumber() == correct,"callCollateralPrice failed");
        });
    });

    it('OptionsFormulas call formulas set', function (){
        var formulasInstance;
        return OptionsFormulas.deployed().then(async function (instance){
            formulasInstance = instance;
            setTwoParamaters(formulasInstance,"getCallLowerDemarcation","setCallLowerDemarcation");
            setTwoParamaters(formulasInstance,"getCallUpperDemarcation","setCallUpperDemarcation");
            setTwoParamaters(formulasInstance,"getCallLowerLimit","setCallLowerLimit");
            setFourParamaters(formulasInstance,"getCallLowerSegment","setCallLowerSegment");
            setFourParamaters(formulasInstance,"getCallMidSegment","setCallMidSegment");
            setFourParamaters(formulasInstance,"getCallUpperSegment","setCallUpperSegment");
        });
    });



    it('OptionsFormulas put formulas get', function (){
        var formulasInstance;
        return OptionsFormulas.deployed().then(async function (instance){
            formulasInstance = instance;
            var result = await formulasInstance.getPutLowerDemarcation();
            assert(result[0]==7 && result[1] == -1,"getPutLowerDemarcation failed");
            result = await formulasInstance.getPutUpperDemarcation();
            assert(result[0]==11 && result[1] == -1,"getPutUpperDemarcation failed");
            result = await formulasInstance.getPutLowerLimit();
            assert(result[0]==1 && result[1] == -2,"getPutLowerLimit failed");
            result = await formulasInstance.getPutLowerSegment();
            assert(result[0]==12 && result[1] == -1 && result[2]==-1 && result[3] == 0,"getPutLowerSegment failed");
            result = await formulasInstance.getPutMidSegment();
            assert(result[0]==5 && result[1] == -1 && result[2]==0 && result[3] == 0,"getPutMidSegment failed");
            result = await formulasInstance.getPutUpperSegment();
            assert(result[0]==11111111111 && result[1] == -10 && result[2]==-5555555556 && result[3] == -10,"getPutUpperSegment failed");
        });
    });
    it('OptionsFormulas Put formulas call', function (){
        var formulasInstance;
        return OptionsFormulas.deployed().then(async function (instance){
            formulasInstance = instance;
            var strickPrice = 100000;
            var currentPrice = strickPrice;
            //mid segment
            var result = await formulasInstance.putCollateralPrice(strickPrice,currentPrice);
            var correct = functionModule.CalPutCollateral(strickPrice,currentPrice);
            assert(result.toNumber() == correct,"putCollateralPrice failed");
            currentPrice = strickPrice*7/10;
            result = await formulasInstance.putCollateralPrice(strickPrice,currentPrice);
            correct = functionModule.CalPutCollateral(strickPrice,currentPrice);
            assert(result.toNumber() == correct,"putCollateralPrice failed");
            currentPrice = strickPrice*11/10;
            result = await formulasInstance.putCollateralPrice(strickPrice,currentPrice);
            correct = functionModule.CalPutCollateral(strickPrice,currentPrice);
            assert(result.toNumber() == correct,"putCollateralPrice failed");
            //lower segment
            currentPrice = strickPrice*5/10;
            result = await formulasInstance.putCollateralPrice(strickPrice,currentPrice);
            correct = functionModule.CalPutCollateral(strickPrice,currentPrice);
            console.log(result.toNumber(),correct);
            assert(result.toNumber() == correct,"putCollateralPrice failed");
            currentPrice = strickPrice*2/10;
            result = await formulasInstance.putCollateralPrice(strickPrice,currentPrice);
            correct = functionModule.CalPutCollateral(strickPrice,currentPrice);
            console.log(result.toNumber(),correct);
            assert(result.toNumber() == correct,"putCollateralPrice failed");
            currentPrice = strickPrice*1/1000;
            result = await formulasInstance.putCollateralPrice(strickPrice,currentPrice);
            correct = functionModule.CalPutCollateral(strickPrice,currentPrice);
            console.log(result.toNumber(),correct);
            assert(result.toNumber() == correct,"putCollateralPrice failed");
            //upper segment
            currentPrice = strickPrice*13/10;
            result = await formulasInstance.putCollateralPrice(strickPrice,currentPrice);
            correct = functionModule.CalPutCollateral(strickPrice,currentPrice);
            console.log(result.toNumber(),correct);
            assert(result.toNumber() == correct,"putCollateralPrice failed");
            currentPrice = strickPrice*16/10;
            result = await formulasInstance.putCollateralPrice(strickPrice,currentPrice);
            correct = functionModule.CalPutCollateral(strickPrice,currentPrice);
            console.log(result.toNumber(),correct);
            assert(result.toNumber() == correct,"putCollateralPrice failed");
            currentPrice = strickPrice*2;
            result = await formulasInstance.putCollateralPrice(strickPrice,currentPrice);
            correct = functionModule.CalPutCollateral(strickPrice,currentPrice);
            console.log(result.toNumber(),correct);
            assert(result.toNumber() == correct,"putCollateralPrice failed");
            currentPrice = strickPrice*10;
            result = await formulasInstance.putCollateralPrice(strickPrice,currentPrice);
            correct = functionModule.CalPutCollateral(strickPrice,currentPrice);
            console.log(result.toNumber(),correct);
            assert(result.toNumber() == correct,"putCollateralPrice failed");
        });
    });
    it('OptionsFormulas put formulas set', function (){
        var formulasInstance;
        return OptionsFormulas.deployed().then(async function (instance){
            formulasInstance = instance;
            setTwoParamaters(formulasInstance,"getPutLowerDemarcation","setPutLowerDemarcation");
            setTwoParamaters(formulasInstance,"getPutUpperDemarcation","setPutUpperDemarcation");
            setTwoParamaters(formulasInstance,"getPutLowerLimit","setPutLowerLimit");
            setFourParamaters(formulasInstance,"getPutLowerSegment","setPutLowerSegment");
            setFourParamaters(formulasInstance,"getPutMidSegment","setPutMidSegment");
            setFourParamaters(formulasInstance,"getPutUpperSegment","setPutUpperSegment");
        });
    });

});
async function setTwoParamaters(instance, getFunction,setFunction){
    var result = await instance[getFunction]();
    await instance[setFunction](11,-3);
    var settings = await instance[getFunction]();
    assert(settings[0].toNumber()==11 && settings[1].toNumber() == -3,setFunction + " failed");
    await instance[setFunction](result[0].toNumber(),result[1].toNumber());
    settings = await instance[getFunction]();
    console.log(settings[0].toNumber(),settings[1].toNumber());
    assert(result[0].toNumber()==settings[0].toNumber() && result[1].toNumber() == settings[1].toNumber(),setFunction+ " failed");
}
async function setFourParamaters(instance, getFunction,setFunction){
    var result = await instance[getFunction]();
    await instance[setFunction](11,-3,15,1);
    var settings = await instance[getFunction]();
    assert(settings[0].toNumber()==11 && settings[1].toNumber() == -3,
    settings[2].toNumber()==15 && settings[3].toNumber() == 1,setFunction + " failed");
    await instance[setFunction](result[0].toNumber(),result[1].toNumber(),result[2].toNumber(),result[3].toNumber());
    settings = await instance[getFunction]();
    console.log(settings[0].toNumber(),settings[1].toNumber());
    assert(result[0].toNumber()==settings[0].toNumber() && result[1].toNumber() == settings[1].toNumber(),
        result[2].toNumber()==settings[2].toNumber() && result[3].toNumber() == settings[3].toNumber(),setFunction+ " failed");
}
