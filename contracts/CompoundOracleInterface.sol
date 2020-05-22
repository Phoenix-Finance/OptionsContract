pragma solidity ^0.4.26;

contract ICompoundOracle {
    /**
  * @notice retrieves price of an asset
  * @dev function to get price for an asset
  * @param asset Asset for which to get the price
  * @return uint mantissa of asset price (scaled by 1e18) or zero if unset or contract paused
  */
    function getPrice(address asset) public view returns (uint);
    function getUnderlyingPrice(uint256 cToken) public view returns (uint);
    function getOptionsPrice(address oToken) public view returns (uint);
    function getSellOptionsPrice(address oToken) public view returns (uint);
    function getBuyOptionsPrice(address oToken) public view returns (uint);

}
