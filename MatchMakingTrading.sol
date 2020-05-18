pragma solidity ^0.4.26;
import "./whiteList.sol";
import "./CompoundOracleInterface.sol";
import "./SafeMath.sol";
import "./IERC20.sol";
contract matchMakingTrading is addressWhiteList{
    using SafeMath for uint256;
    struct OptionsOrder {
        address owner;
        uint256 createdTime;
        uint256 amount;
    }
    ICompoundOracle _oracle;
    //mapping settlementsCurrency => OptionsToken => OptionsOrder
    mapping(address => mapping(address => OptionsOrder[])) public payOrderMap;
    mapping(address => mapping(address => OptionsOrder[])) public sellOrderMap;
    
    
    OptionsOrder[] public payOrderList;
    OptionsOrder[] public sellOrderList;
    function addPayOrder(address optionsToken,address settlementsCurrency,amount deposit,uint256 buyAmount) public payable{
        require(isEligibleAddress(settlementsCurrency),"This settlements currency is ineligible");
        payOrderMap[settlementsCurrency][optionsToken].push(OptionsOrder(msg.sender,now,buyAmount));
    }
    function addSellOrder(address optionsToken,address settlementsCurrency,uint256 amount) public {
        require(isEligibleAddress(settlementsCurrency),"This settlements currency is ineligible");
        sellOrderMap[settlementsCurrency][optionsToken].push(OptionsOrder(msg.sender,now,amount));
    }
    function matchPayOrder(address optionsToken,address settlementsCurrency,address amount)public{
        OptionsOrder[] storage orderList = payOrderMap[settlementsCurrency][optionsToken];
        for (uint256 i=0;i<orderList.length;i++){
            orderList[i].amount;
        }
    }
    function _orderTrading(address optionsToken,address settlementsCurrency, address seller,address buyer,uint256 amount){
        uint256 tokenPrice = _oracle.getPrice(optionsToken);
        uint256 currencyPrice = _oracle.getPrice(settlementsCurrency);
        uint256 currencyAmount = tokenPrice.mul(amount).div(currencyPrice);
        IERC20 erc20Token = IERC20(optionsToken);
        erc20Token.transfer(buyer,amount);
        if (settlementsCurrency == address(0)){
            seller.transfer(currencyAmount);
            
        }else{
            IERC20 settlement = IERC20(settlementsCurrency);
            settlement.transfer(seller,currencyAmount);
           
        }
        
    }
}