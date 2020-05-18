pragma solidity ^0.4.26;
import "./Ownable.sol";
contract AddressWhiteList is Ownable{
    address[] whiteList;
    function addWhiteList(address addAddress)public onlyOwner{
        whiteList.push(addAddress);
    }
    function removeWhiteList(address removeAddress)public onlyOwner{
        for (uint256 i=0;i<whiteList.length;i++){
            if (whiteList[i] == removeAddress){
                if (i!=whiteList.length-1){
                    whiteList[i] = whiteList[whiteList.length-1];
                }
                whiteList.length--;
                return;
            }
        }
    }
    function getWhiteList()public view returns (address[]){
        return whiteList;
    }
    function isEligibleAddress(address tmpAddress) public view returns (bool){
        for (uint256 i=0;i<whiteList.length;i++){
            if (whiteList[i] == tmpAddress)
                return true;
        }
        return false;
    }
}