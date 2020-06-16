pragma solidity ^0.4.26;

import "./Ownable.sol";
import "./SafeMath.sol";
import "./OptionsToken.sol";
interface IOptFormulas {
    function callCollateralPrice(uint256 _strikePrice,uint256 _currentPrice)external view returns(uint256);
    function putCollateralPrice(uint256 _strikePrice,uint256 _currentPrice)external view returns(uint256);
    function createNewToken(uint256 expiration,string optionsTokenName)external returns(address);
    function calculateMaxMintAmount(uint256 collateralPrice,uint256 collateralAmount,uint256 strikePrice,uint256 underlyingPrice,uint8 optType)
            external returns (uint256);
}

contract OptionsFormulas is Ownable{
    using SafeMath for uint256;
    /* represents floting point numbers, where number = value * 10 ** exponent
        i.e 0.1 = 10 * 10 ** -3 */
    struct Number {
        int256 value;
        int32 exponent;
    }
    struct CollateralSegment {
        Number strikeSlope;
        Number priceSlope;
    }
    struct ThreeSegments {
        //the lower limit of the result
        Number lowerLimit;
        // three segments demarcation points
        Number lowerDemarcation;
        Number upperDemarcation;
        //Lower segment
        CollateralSegment lowerSegment;
        CollateralSegment midSegment;
        CollateralSegment upperSegment;
    }

    ThreeSegments public callCollateral;
    ThreeSegments public putCollateral;
    constructor () public {
        //call options formulas
        
        callCollateral.lowerLimit = Number(1,-2);
        //from 0.9*strikeprice to 1.3*strikeprice
        callCollateral.lowerDemarcation = Number(9,-1);
        callCollateral.upperDemarcation = Number(13,-1);
        // LowerSegment formulas is NeedCollateral = 0*strikeprice + 5/9*price;
        callCollateral.lowerSegment.strikeSlope = Number(0,0);
        callCollateral.lowerSegment.priceSlope = Number(5555555556,-10);
        //midSegment formulas is NeedCollateral = 0.5*strikeprice + 0*price;
        callCollateral.midSegment.strikeSlope = Number(5,-1);
        callCollateral.midSegment.priceSlope = Number(0,0);
        //UpperSegment formulas is NeedCollateral = 1*price - 0.8*strikeprice
        callCollateral.upperSegment.strikeSlope = Number(-8,-1);
        callCollateral.upperSegment.priceSlope = Number(1,0);
        //Put options formulas
        
        putCollateral.lowerLimit = Number(1,-2);
        //from 0.7*strikeprice to 1.1*strikeprice
        putCollateral.lowerDemarcation = Number(7,-1);
        putCollateral.upperDemarcation = Number(11,-1);
        // LowerSegment formulas is NeedCollateral = 1.2*strikeprice -price;
        putCollateral.lowerSegment.strikeSlope = Number(12,-1);
        putCollateral.lowerSegment.priceSlope = Number(-1,0);
        //midSegment formulas is NeedCollateral = 0.5*strikeprice + 0*price;
        putCollateral.midSegment.strikeSlope = Number(5,-1);
        putCollateral.midSegment.priceSlope = Number(0,0);
        //UpperSegment formulas is NeedCollateral = -5/9*price + 10/9*strikeprice
        putCollateral.upperSegment.strikeSlope = Number(11111111111,-10);
        putCollateral.upperSegment.priceSlope = Number(-5555555556,-10);     
    }
    //*****************************getter**********************************

    //****************************Call Formulas***************************
    function getCallLowerDemarcation()public view returns (int256,int32){
        return (callCollateral.lowerDemarcation.value,callCollateral.lowerDemarcation.exponent);
    }
    function getCallUpperDemarcation()public view returns (int256,int32){
        return (callCollateral.upperDemarcation.value,callCollateral.upperDemarcation.exponent);
    }
    function getCallLowerLimit()public view returns (int256,int32){
        return (callCollateral.lowerLimit.value,callCollateral.lowerLimit.exponent);
    }
    function getCallLowerSegment()public view returns(int256,int32,int256,int32){
        return (callCollateral.lowerSegment.strikeSlope.value,callCollateral.lowerSegment.strikeSlope.exponent,
        callCollateral.lowerSegment.priceSlope.value,callCollateral.lowerSegment.priceSlope.exponent);
    }
    function getCallMidSegment()public view returns(int256,int32,int256,int32){
        return (callCollateral.midSegment.strikeSlope.value,callCollateral.midSegment.strikeSlope.exponent,
        callCollateral.midSegment.priceSlope.value,callCollateral.midSegment.priceSlope.exponent);
    }
    function getCallUpperSegment()public view returns(int256,int32,int256,int32){
        return (callCollateral.upperSegment.strikeSlope.value,callCollateral.upperSegment.strikeSlope.exponent,
        callCollateral.upperSegment.priceSlope.value,callCollateral.upperSegment.priceSlope.exponent);
    }

    //****************************Put Formulas***************************
    function getPutLowerDemarcation()public view returns (int256,int32){
        return (putCollateral.lowerDemarcation.value,putCollateral.lowerDemarcation.exponent);
    }
    function getPutUpperDemarcation()public view returns (int256,int32){
        return (putCollateral.upperDemarcation.value,putCollateral.upperDemarcation.exponent);
    }
    function getPutLowerLimit()public view returns (int256,int32){
        return (putCollateral.lowerLimit.value,putCollateral.lowerLimit.exponent);
    }
    function getPutLowerSegment()public view returns(int256,int32,int256,int32){
        return (putCollateral.lowerSegment.strikeSlope.value,putCollateral.lowerSegment.strikeSlope.exponent,
        putCollateral.lowerSegment.priceSlope.value,putCollateral.lowerSegment.priceSlope.exponent);
    }
    function getPutMidSegment()public view returns(int256,int32,int256,int32){
        return (putCollateral.midSegment.strikeSlope.value,putCollateral.midSegment.strikeSlope.exponent,
        putCollateral.midSegment.priceSlope.value,putCollateral.midSegment.priceSlope.exponent);
    }
    function getPutUpperSegment()public view returns(int256,int32,int256,int32){
        return (putCollateral.upperSegment.strikeSlope.value,putCollateral.upperSegment.strikeSlope.exponent,
        putCollateral.upperSegment.priceSlope.value,putCollateral.upperSegment.priceSlope.exponent);
    }
    //*****************************setter**********************************

    //****************************Call Formulas***************************
    function setCallLowerDemarcation(int256 _value,int32 _exponent)public onlyOwner{
        callCollateral.lowerDemarcation.value = _value;
        callCollateral.lowerDemarcation.exponent = _exponent;
    }
    function setCallUpperDemarcation(int256 _value,int32 _exponent)public onlyOwner{
        callCollateral.upperDemarcation.value = _value;
        callCollateral.upperDemarcation.exponent = _exponent;
    }
    function setCallLowerLimit(int256 _value,int32 _exponent)public onlyOwner{
        callCollateral.lowerLimit.value = _value;
        callCollateral.lowerLimit.exponent = _exponent;
    }
    function setCallLowerSegment(int256 _strikeSlopeValue,
                                int32 _strickSlopeExponent,
                                int256 _priceSlopeValue,
                                int32 _priceSlopeExponent)public onlyOwner
    {
        callCollateral.lowerSegment.strikeSlope.value = _strikeSlopeValue;
        callCollateral.lowerSegment.strikeSlope.exponent = _strickSlopeExponent;
        callCollateral.lowerSegment.priceSlope.value = _priceSlopeValue;
        callCollateral.lowerSegment.priceSlope.exponent = _priceSlopeExponent;
    }
    function setCallMidSegment(int256 _strikeSlopeValue,
        int32 _strickSlopeExponent,
        int256 _priceSlopeValue,
        int32 _priceSlopeExponent)public onlyOwner
    {
        callCollateral.midSegment.strikeSlope.value = _strikeSlopeValue;
        callCollateral.midSegment.strikeSlope.exponent = _strickSlopeExponent;
        callCollateral.midSegment.priceSlope.value = _priceSlopeValue;
        callCollateral.midSegment.priceSlope.exponent = _priceSlopeExponent;
    }
    function setCallUpperSegment(int256 _strikeSlopeValue,
        int32 _strickSlopeExponent,
        int256 _priceSlopeValue,
        int32 _priceSlopeExponent)public onlyOwner
    {
        callCollateral.upperSegment.strikeSlope.value = _strikeSlopeValue;
        callCollateral.upperSegment.strikeSlope.exponent = _strickSlopeExponent;
        callCollateral.upperSegment.priceSlope.value = _priceSlopeValue;
        callCollateral.upperSegment.priceSlope.exponent = _priceSlopeExponent;
    }

    //****************************Put Formulas***************************
    function setPutLowerDemarcation(int256 _value,int32 _exponent)public onlyOwner{
        putCollateral.lowerDemarcation.value = _value;
        putCollateral.lowerDemarcation.exponent = _exponent;
    }
    function setPutUpperDemarcation(int256 _value,int32 _exponent)public onlyOwner{
        putCollateral.upperDemarcation.value = _value;
        putCollateral.upperDemarcation.exponent = _exponent;
    }
    function setPutLowerLimit(int256 _value,int32 _exponent)public onlyOwner{
        putCollateral.lowerLimit.value = _value;
        putCollateral.lowerLimit.exponent = _exponent;
    }
    function setPutLowerSegment(int256 _strikeSlopeValue,
        int32 _strickSlopeExponent,
        int256 _priceSlopeValue,
        int32 _priceSlopeExponent)public onlyOwner
    {
        putCollateral.lowerSegment.strikeSlope.value = _strikeSlopeValue;
        putCollateral.lowerSegment.strikeSlope.exponent = _strickSlopeExponent;
        putCollateral.lowerSegment.priceSlope.value = _priceSlopeValue;
        putCollateral.lowerSegment.priceSlope.exponent = _priceSlopeExponent;
    }
    function setPutMidSegment(int256 _strikeSlopeValue,
        int32 _strickSlopeExponent,
        int256 _priceSlopeValue,
        int32 _priceSlopeExponent)public onlyOwner
    {
        putCollateral.midSegment.strikeSlope.value = _strikeSlopeValue;
        putCollateral.midSegment.strikeSlope.exponent = _strickSlopeExponent;
        putCollateral.midSegment.priceSlope.value = _priceSlopeValue;
        putCollateral.midSegment.priceSlope.exponent = _priceSlopeExponent;
    }
    function setPutUpperSegment(int256 _strikeSlopeValue,
        int32 _strickSlopeExponent,
        int256 _priceSlopeValue,
        int32 _priceSlopeExponent)public onlyOwner
    {
        putCollateral.upperSegment.strikeSlope.value = _strikeSlopeValue;
        putCollateral.upperSegment.strikeSlope.exponent = _strickSlopeExponent;
        putCollateral.upperSegment.priceSlope.value = _priceSlopeValue;
        putCollateral.upperSegment.priceSlope.exponent = _priceSlopeExponent;
    }
    //****************************Formulas call***********************************************
    function callCollateralPrice(uint256 _strikePrice,uint256 _currentPrice)public view returns(uint256){
        return _calCollateralPrice(callCollateral,_strikePrice,_currentPrice);
    }
    function putCollateralPrice(uint256 _strikePrice,uint256 _currentPrice)public view returns(uint256){
        return _calCollateralPrice(putCollateral,_strikePrice,_currentPrice);
    }
    function createNewToken(uint256 expiration,string optionsTokenName)public returns(address){
        OptionsToken optionsToken = new OptionsToken(expiration,optionsTokenName);
        optionsToken.setManager(msg.sender);
        optionsToken.transferOwnership(msg.sender);
        return optionsToken;
    }
    function calculateMaxMintAmount(uint256 collateralPrice,uint256 collateralAmount,uint256 strikePrice,uint256 underlyingPrice,uint8 optType)
            public view returns (uint256){
        uint256 collateralValue = collateralAmount.mul(collateralPrice);
        uint256 needCollateral = (optType == 0) ? callCollateralPrice(strikePrice,underlyingPrice) : putCollateralPrice(strikePrice,underlyingPrice);
        return collateralValue.div(needCollateral);
    }
    //******************************Internal functions******************************************
    function _calNumberMulUint(Number number,uint256 value) internal pure returns (uint256,bool){
        bool bSignFlag = number.value >= 0;
        uint256 result = bSignFlag ? uint256(number.value).mul(value) : uint256(-1*number.value).mul(value);
        result = number.exponent > 0 ? result.mul(10**uint256(number.exponent)) : result.div(10**uint256(-1*number.exponent));
        return (result , bSignFlag);
    }
    function _calSegmentPrice(CollateralSegment storage _segment,uint256 _strikePrice,uint256 _currentPrice)
            internal view
            returns (uint256){
        uint256 result;
        (uint256 strikeResult,bool strikeSign) = _calNumberMulUint(_segment.strikeSlope,_strikePrice);
        (uint256 priceResult,bool priceSign) = _calNumberMulUint(_segment.priceSlope,_currentPrice);
        if (strikeSign && priceSign){
            result = strikeResult.add(priceResult);
        }else if(strikeSign){
            if(strikeResult > priceResult){
                result = strikeResult.sub(priceResult);
            }else{
                result = 0;
            }
        }else if(priceSign) {
            if (priceResult > strikeResult){
                result = priceResult.sub(strikeResult);
            }else{
                result = 0;
            }
        }else{
            result = 0;
        }
        return result;
    }
    function _calCollateralPrice(ThreeSegments storage _collateral,uint256 _strikePrice,uint256 _currentPrice)
            internal view
            returns (uint256){
        uint256 result;
        (uint256 lowerDemarcation,bool lowerSign) = _calNumberMulUint(_collateral.lowerDemarcation,_strikePrice);
        assert(lowerSign);
        (uint256 upperDemarcation,bool upperSign) = _calNumberMulUint(_collateral.upperDemarcation,_strikePrice);
        assert(upperSign);
        if (_currentPrice > upperDemarcation){
            result = _calSegmentPrice(_collateral.upperSegment,_strikePrice,_currentPrice);
        }else if(_currentPrice>lowerDemarcation){
            result = _calSegmentPrice(_collateral.midSegment,_strikePrice,_currentPrice);
        }else{
            result = _calSegmentPrice(_collateral.lowerSegment,_strikePrice,_currentPrice);
        }
        (uint256 lowerLimit,bool limitSign) = _calNumberMulUint(_collateral.lowerLimit,_strikePrice);
        assert(limitSign);
        if (result<lowerLimit){
            result = lowerLimit;
        }
        return result;
    }
}
