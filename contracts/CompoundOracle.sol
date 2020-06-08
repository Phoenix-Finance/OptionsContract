pragma solidity ^0.4.26;
import "./CompoundOracleInterface.sol";
import "./Ownable.sol";

contract CompoundOracle is ICompoundOracle,Ownable {

    mapping(uint256 => uint256) private priceMap;
    /**
      * @notice set price of an asset
      * @dev function to set price for an asset
      * @param asset Asset for which to set the price
      * @param price the Asset's price
      */    
    function setPrice(address asset,uint256 price) public onlyOwner {
        priceMap[uint256(asset)] = price;
    }
    /**
      * @notice set price of an underlying
      * @dev function to set price for an underlying
      * @param underlying underlying for which to set the price
      * @param price the underlying's price
      */  
    function setUnderlyingPrice(uint256 underlying,uint256 price) public onlyOwner {
        require(underlying>0 , "underlying cannot be zero");
        priceMap[underlying] = price;
    }
    /**
      * @notice set price of an options token sell price
      * @dev function to set an options token sell price
      * @param optoken options token for which to set the sell price
      * @param price the options token sell price
      */     
    function setSellOptionsPrice(address optoken,uint256 price) public onlyOwner {
        uint256 key = uint256(optoken)*10+1;
        priceMap[key] = price;
    }
    /**
      * @notice set price of an options token buy price
      * @dev function to set an options token buy price
      * @param optoken options token for which to set the buy price
      * @param price the options token buy price
      */      
    function setBuyOptionsPrice(address optoken,uint256 price) public onlyOwner {
        uint256 key = uint256(optoken)*10+2;
        priceMap[key] = price;
    }
        /**
  * @notice retrieves price of an asset
  * @dev function to get price for an asset
  * @param asset Asset for which to get the price
  * @return uint mantissa of asset price (scaled by 1e18) or zero if unset or contract paused
  */
    function getPrice(address asset) public view returns (uint){
        return priceMap[uint256(asset)];
    }
    function getUnderlyingPrice(uint256 underlying) public view returns (uint256){
        return priceMap[underlying];
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
