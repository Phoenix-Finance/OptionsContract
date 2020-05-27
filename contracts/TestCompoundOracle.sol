pragma solidity ^0.4.26;
import "./CompoundOracle.sol";

contract TestCompoundOracle is CompoundOracle {
    /**
  * @notice retrieves price of an asset
  * @dev function to get price for an asset
  * @param asset Asset for which to get the price
  * @return uint mantissa of asset price (scaled by 1e18) or zero if unset or contract paused
  */
    function getPrice(address asset) public view returns (uint){
        uint256 price = CompoundOracle.getPrice(asset);
        if (price != 0) {
            return price;
        }
        return 50;
    }
    function getUnderlyingPrice(uint256 cToken) public view returns (uint){
        uint256 price = CompoundOracle.getUnderlyingPrice(cToken);
        if (price != 0) {
            return price;
        }
        return 200;
    }

    function getOptionsPrice(address oToken) public view returns (uint){
        uint256 price = CompoundOracle.getOptionsPrice(oToken);
        if (price != 0) {
            return price;
        }
        return 100;
    }
    function getSellOptionsPrice(address oToken) public view returns (uint){
        uint256 price = CompoundOracle.getSellOptionsPrice(oToken);
        if (price != 0) {
            return price;
        }
        return 90;
    }
    function getBuyOptionsPrice(address oToken) public view returns (uint){
        uint256 price = CompoundOracle.getBuyOptionsPrice(oToken);
        if (price != 0) {
            return price;
        }
        return 110;
    }

}
