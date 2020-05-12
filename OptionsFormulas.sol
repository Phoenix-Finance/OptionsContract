pragma solidity ^0.4.26;

import "./Ownable.sol";
import "./SafeMath.sol";

interface IOptFormulas {
    function callCollateralPrice(uint256 _strikePrice,uint256 _currentPrice)external view returns(uint256);
    function putCollateralPrice(uint256 _strikePrice,uint256 _currentPrice)external view returns(uint256);
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
    function setCallLowerDemarcation(int256 _value,int32 _exponent)public onlyowner{
        callCollateral.lowerDemarcation.value = _value;
        callCollateral.lowerDemarcation.exponent - _exponent;
    }
    function setCallUpperDemarcation(int256 _value,int32 _exponent)public onlyowner{
        callCollateral.upperDemarcation.value = _value;
        callCollateral.upperDemarcation.exponent - _exponent;
    }
    function setCallLowerLimit(int256 _value,int32 _exponent)public onlyowner{
        callCollateral.lowerLimit.value = _value;
        callCollateral.lowerLimit.exponent - _exponent;
    }
    function setCallLowerSegment(int256 _strikeSlopeValue,
                                int32 _strickSlopeExponent,
                                int256 _priceSlopeValue,
                                int32 _priceSlopeExponent)public onlyowner
    {
        callCollateral.lowerSegment.strikeSlope.value = _strikeSlopeValue;
        callCollateral.lowerSegment.strikeSlope.exponent = _strickSlopeExponent;
        callCollateral.lowerSegment.priceSlope.value = _priceSlopeValue;
        callCollateral.lowerSegment.priceSlope.exponent = _priceSlopeExponent;
    }
    function getCallMidSegment(int256 _strikeSlopeValue,
        int32 _strickSlopeExponent,
        int256 _priceSlopeValue,
        int32 _priceSlopeExponent)public onlyowner
    {
        callCollateral.midSegment.strikeSlope.value = _strikeSlopeValue;
        callCollateral.midSegment.strikeSlope.exponent = _strickSlopeExponent;
        callCollateral.midSegment.priceSlope.value = _priceSlopeValue;
        callCollateral.midSegment.priceSlope.exponent = _priceSlopeExponent;
    }
    function getCallUpperSegment(int256 _strikeSlopeValue,
        int32 _strickSlopeExponent,
        int256 _priceSlopeValue,
        int32 _priceSlopeExponent)public onlyowner
    {
        callCollateral.upperSegment.strikeSlope.value = _strikeSlopeValue;
        callCollateral.upperSegment.strikeSlope.exponent = _strickSlopeExponent;
        callCollateral.upperSegment.priceSlope.value = _priceSlopeValue;
        callCollateral.upperSegment.priceSlope.exponent = _priceSlopeExponent;
    }

    //****************************Put Formulas***************************
    function setPutLowerDemarcation(int256 _value,int32 _exponent)public onlyowner{
        putCollateral.lowerDemarcation.value = _value;
        putCollateral.lowerDemarcation.exponent - _exponent;
    }
    function setPutUpperDemarcation(int256 _value,int32 _exponent)public onlyowner{
        putCollateral.upperDemarcation.value = _value;
        putCollateral.upperDemarcation.exponent - _exponent;
    }
    function setPutLowerLimit(int256 _value,int32 _exponent)public onlyowner{
        putCollateral.lowerLimit.value = _value;
        putCollateral.lowerLimit.exponent - _exponent;
    }
    function setPutLowerSegment(int256 _strikeSlopeValue,
        int32 _strickSlopeExponent,
        int256 _priceSlopeValue,
        int32 _priceSlopeExponent)public onlyowner
    {
        putCollateral.lowerSegment.strikeSlope.value = _strikeSlopeValue;
        putCollateral.lowerSegment.strikeSlope.exponent = _strickSlopeExponent;
        putCollateral.lowerSegment.priceSlope.value = _priceSlopeValue;
        putCollateral.lowerSegment.priceSlope.exponent = _priceSlopeExponent;
    }
    function getPutMidSegment(int256 _strikeSlopeValue,
        int32 _strickSlopeExponent,
        int256 _priceSlopeValue,
        int32 _priceSlopeExponent)public onlyowner
    {
        putCollateral.midSegment.strikeSlope.value = _strikeSlopeValue;
        putCollateral.midSegment.strikeSlope.exponent = _strickSlopeExponent;
        putCollateral.midSegment.priceSlope.value = _priceSlopeValue;
        putCollateral.midSegment.priceSlope.exponent = _priceSlopeExponent;
    }
    function getPutUpperSegment(int256 _strikeSlopeValue,
        int32 _strickSlopeExponent,
        int256 _priceSlopeValue,
        int32 _priceSlopeExponent)public onlyowner
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

    //******************************Internal functions******************************************
    function _calNumberMulUint(Number number,uint256 value) internal returns (uint256,bool){
        bool bSignFlag = true;
        uint256 result;
        if (number.value < 0){
            bSignFlag = false;
            result = uint256(-1*number.value).mul(value);
        }else{
            result = uint256(number.value).mul(value);
        }
        if (number.exponent > 0) {
            result = result.mul(10**uint256(number.exponent));
        } else {
            result = result.div(10**uint256(-1*number.exponent));
        }
        return (result , bSignFlag);
    }
    function _calSegmentPrice(CollateralSegment storage _segment,uint256 _strikePrice,uint256 _currentPrice)
            internal
            returns (uint256){
        uint256 result;
        uint256 strikeResult;
        bool strikeSign;
        (strikeResult,strikeSign) = _calNumberMulUint(_segment.strikeSlope,_strikePrice);
        uint256 priceResult;
        bool priceSign;
        (priceResult,priceSign) = _calNumberMulUint(_segment.priceSlope,_currentPrice);
        if (strikeSign && priceSign){
            result = strikeResult.add(priceResult);
        }else if(strikeSign){
            result = strikeResult.sub(priceResult);
        }else if(priceSign) {
            result = priceResult.sub(strikeResult);
        }else{
            //err;
        }
        return result;
    }
    function _calCollateralPrice(ThreeSegments storage _collateral,uint256 _strikePrice,uint256 _currentPrice)
            internal
            returns (uint256){
        uint256 result;
        uint256 lowerDemarcation;
        bool lowerSign;
        (lowerDemarcation,lowerSign) = _calNumberMulUint(_collateral.lowerDemarcation,_strikePrice);
        assert(lowerSign);
        uint256 upperDemarcation;
        bool upperSign;
        (upperDemarcation,upperSign) = _calNumberMulUint(_collateral.upperDemarcation,_strikePrice);
        assert(upperSign);
        if (_currentPrice > upperDemarcation){
            result = _calSegmentPrice(_collateral.upperSegment,_strikePrice,_currentPrice);
        }else if(_currentPrice>lowerDemarcation){
            result = _calSegmentPrice(_collateral.midSegment,_strikePrice,_currentPrice);
        }else{
            result = _calSegmentPrice(_collateral.lowerSegment,_strikePrice,_currentPrice);
        }
        uint256 lowerLimit;
        bool limitSign;
        (lowerLimit,limitSign) = _calNumberMulUint(_collateral.lowerLimit,_strikePrice);
        assert(limitSign);
        if (result<lowerLimit){
            result = lowerLimit;
        }
        return result;
    }
}
