pragma solidity ^0.4.26;

interface IIterableToken {
    //function iterator
    function iterate_balance_start() external view returns (uint);
    function iterate_balance_valid( uint keyIndex)external view returns (bool);
    function iterate_balance_next(uint keyIndex)external view returns (uint);
    function iterate_balance_get(uint keyIndex)external view returns (address, uint256);
    function getAccountsAndBalances()public view returns (address[],uint256[]);
    function burn(uint256 amount) external returns (bool);
    function mint(address account,uint256 amount) external returns (bool);
}