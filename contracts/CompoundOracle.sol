pragma solidity ^0.4.26;
import "./CompoundOracleInterface.sol";
import "./Ownable.sol";

contract CompoundOracle is ICompoundOracle,Ownable {
    /**
  * @notice retrieves price of an asset
  * @dev function to get price for an asset
  * @param asset Asset for which to get the price
  * @return uint mantissa of asset price (scaled by 1e18) or zero if unset or contract paused
  */
    mapping(uint256 => uint256) private priceMap;
    function setPrice(address asset,uint256 price) public onlyOwner {
        priceMap[uint256(asset)] = price;
    }
    function setUnderlyingPrice(uint256 underlying,uint256 price) public onlyOwner {
        require(underlying>0 , "underlying cannot be zero");
        priceMap[underlying] = price;
    }
    function setOptionsPrice(address optoken,uint256 price) public onlyOwner {
        priceMap[uint256(optoken)] = price;
    }
    function setSellOptionsPrice(address optoken,uint256 price) public onlyOwner {
        uint256 key = uint256(optoken)*10+1;
        priceMap[key] = price;
    }
    function setBuyOptionsPrice(address optoken,uint256 price) public onlyOwner {
        uint256 key = uint256(optoken)*10+2;
        priceMap[key] = price;
    }
    function getPrice(address asset) public view returns (uint){
        return priceMap[uint256(asset)];
    }
    function getUnderlyingPrice(uint256 underlying) public view returns (uint256){
        return priceMap[underlying];
    }

    function getOptionsPrice(address oToken) public view returns (uint256){
        return priceMap[uint256(oToken)];
    }
    function getSellOptionsPrice(address oToken) public view returns (uint256){
        uint256 key = uint256(oToken)*10+1;
        return priceMap[key];

    }
    function getBuyOptionsPrice(address oToken) public view returns (uint256){
        uint256 key = uint256(oToken)*10+2;
        return priceMap[key];
    }

}
