pragma solidity ^0.4.26;

interface IOptionsManager {
    //function iterator
    function getOptionsTokenInfo(address tokenAddress)external view returns (uint8,address,uint32,uint256,uint256,bool);
}