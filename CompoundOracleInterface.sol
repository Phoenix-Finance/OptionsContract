pragma solidity ^0.4.0;

contract ICompoundOracle {
    /**
  * @notice retrieves price of an asset
  * @dev function to get price for an asset
  * @param asset Asset for which to get the price
  * @return uint mantissa of asset price (scaled by 1e18) or zero if unset or contract paused
  */
    function getPrice(address asset) public view returns (uint);
    function getUnderlyingPrice(ERC20 cToken) public view returns (uint);
    function getOptionsPrice(ERC20 oToken) public view returns (uint);

}
