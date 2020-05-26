pragma solidity ^0.4.26;
import "./TransactionFee.sol";
import "./CompoundOracleInterface.sol";
import "./SafeMath.sol";
import "./IERC20.sol";
contract matchMakingTrading is TransactionFee{
    using SafeMath for uint256;
    struct SellOptionsOrder {
        address owner;
        uint256 createdTime;
        uint256 amount;
    }
    struct PayOptionsOrder {
        address owner;
        uint256 createdTime;
        uint256 amount;
        uint256 settlementsAmount;
    }
    ICompoundOracle _oracle;
    //mapping settlementsCurrency => OptionsToken => OptionsOrder
    mapping(address => mapping(address => PayOptionsOrder[])) public payOrderMap;
    mapping(address => mapping(address => SellOptionsOrder[])) public sellOrderMap;
    

    function addPayOrder(address optionsToken,address settlementsCurrency,uint256 deposit,uint256 buyAmount) public payable{
        require(isEligibleAddress(settlementsCurrency),"This settlements currency is ineligible");
        uint256 tokenPrice = _oracle.getPrice(optionsToken);
        uint256 currencyPrice = _oracle.getPrice(settlementsCurrency);
        var (optionsPay,transFee) = _calPayment(buyAmount,tokenPrice,currencyPrice);
        uint256 settlements = deposit;
        if (settlementsCurrency == address(0)){
            settlements = msg.value;
        }else{
            IERC20 settlement = IERC20(settlementsCurrency);
            settlement.transferFrom(msg.sender,address(this),settlements);           
        }
        if (optionsPay.add(transFee)>settlements){
            //Deposit is unsufficient;
            return;
        }
        payOrderMap[settlementsCurrency][optionsToken].push(PayOptionsOrder(msg.sender,now,buyAmount,settlements));
    }
    function addSellOrder(address optionsToken,address settlementsCurrency,uint256 amount) public {
        require(isEligibleAddress(settlementsCurrency),"This settlements currency is ineligible");
        IERC20 ERC20Token = IERC20(optionsToken);
        ERC20Token.transferFrom(msg.sender,address(this),amount);  
        sellOrderMap[settlementsCurrency][optionsToken].push(SellOptionsOrder(msg.sender,now,amount));
    }
    function buyOptionsToken(address optionsToken,uint256 amount,address settlementsCurrency,uint256 currencyAmount) public payable {
        uint256 tokenPrice = _oracle.getBuyOptionsPrice(optionsToken);
        uint256 currencyPrice = _oracle.getPrice(settlementsCurrency);
        if (settlementsCurrency == address (0)) {
            currencyAmount = msg.value;
        }
        uint256 allPay = 0;
        uint256 transFee = 0;
        (allPay,transFee) = _calPayment(amount,tokenPrice,currencyPrice);
        if (allPay.add(transFee) > currencyAmount){
            return;
        }
        SellOptionsOrder[] storage orderList = sellOrderMap[settlementsCurrency][optionsToken];
        for (uint256 i=0;i<orderList.length;i++) {
            uint256 optionsAmount = amount;
            if (amount > orderList[i].amount) {
                optionsAmount = orderList[i].amount;
            }
            amount = amount.sub(optionsAmount);
            uint256 sellAmount = 0;
            (sellAmount,currencyAmount) = _orderTrading(optionsToken,optionsAmount,tokenPrice,settlementsCurrency,currencyAmount,currencyPrice,
            orderList[i].owner,msg.sender);
            orderList[i].amount = orderList[i].amount.sub(sellAmount);
            if (amount == 0) {
                break;
            }
        }
        if (currencyAmount > 0) {
            if (settlementsCurrency == address(0)) {
                msg.sender.transfer(currencyAmount);                
            }else {
                IERC20 settlement = IERC20(settlementsCurrency);
                settlement.transfer(msg.sender,currencyAmount);           
            }           
        }
        _removeEmptySellOrder(optionsToken,settlementsCurrency);
    }
    function sellOptionsToken(address optionsToken,uint256 amount,address settlementsCurrency) public {
        uint256 tokenPrice = _oracle.getSellOptionsPrice(optionsToken);
        uint256 currencyPrice = _oracle.getPrice(settlementsCurrency);
        PayOptionsOrder[] storage orderList = payOrderMap[settlementsCurrency][optionsToken];
        for (uint256 i=0;i<orderList.length;i++){
            uint256 allPay = 0;
            uint256 transFee = 0;
            (allPay,transFee) = _calPayment(orderList[i].amount,tokenPrice,currencyPrice);
            if (allPay.add(transFee) > orderList[i].settlementsAmount){
                continue;
            }
            uint256 optionsAmount = amount;
            if (optionsAmount > orderList[i].amount) {
                optionsAmount = orderList[i].amount;
            }

            amount = amount.sub(optionsAmount);
            uint256 sellAmount = 0;
            uint256 leftCurrency = 0;
            (sellAmount,leftCurrency) = _orderTrading(optionsToken,optionsAmount,tokenPrice,settlementsCurrency,orderList[i].settlementsAmount,currencyPrice,
            msg.sender,orderList[i].owner);
            orderList[i].amount = orderList[i].amount.sub(sellAmount);
            orderList[i].amount = orderList[i].amount.sub(sellAmount);
            orderList[i].settlementsAmount = leftCurrency;
            if (amount == 0) {
                break;
            }
        }
        _removeEmptyPayOrder(optionsToken,settlementsCurrency);
    }
    function _orderTrading(address optionsToken,uint256 amount,uint256 optionsPrice,
            address settlementsCurrency,uint256 currencyAmount,uint256 currencyPrice,
            address seller,address buyer) internal returns (uint256,uint256) {
        uint256 optionsPay = 0;
        uint256 transFee = 0;
        (optionsPay,transFee) = _calPayment(amount,optionsPrice,currencyPrice);
        if (optionsPay.add(transFee)>currencyAmount){
            return (0,currencyAmount);
        }
        IERC20 erc20Token = IERC20(optionsToken);
        erc20Token.transfer(buyer,amount);
        if (settlementsCurrency == address(0)){
            seller.transfer(optionsPay);
            
        }else{
            IERC20 settlement = IERC20(settlementsCurrency);
            settlement.transfer(seller,optionsPay);           
        }
        optionsPay = optionsPay.add(transFee);
        currencyAmount = currencyAmount.sub(optionsPay);
        _addTransactionFee(settlementsCurrency,transFee);
        return (amount,currencyAmount);
    }
    function _removeEmptyPayOrder(address optionsToken,address settlementsCurrency)internal{
        PayOptionsOrder[] storage orderList = payOrderMap[settlementsCurrency][optionsToken];
        uint256 index = 0;
        for (uint i=0;i<orderList.length;i++) {
            if (orderList[i].amount > 0) {
                if(i != index) {
                    payOrderMap[settlementsCurrency][optionsToken][index].owner = orderList[i].owner;
                    payOrderMap[settlementsCurrency][optionsToken][index].createdTime = orderList[i].createdTime;
                    payOrderMap[settlementsCurrency][optionsToken][index].amount = orderList[i].amount;
                    payOrderMap[settlementsCurrency][optionsToken][index].settlementsAmount = orderList[i].settlementsAmount;
                }
                index++;
            }else {
                if (orderList[i].settlementsAmount > 0) {
                    if (settlementsCurrency == address(0)) {
                        orderList[i].owner.transfer(orderList[i].settlementsAmount);                
                    }else {
                        IERC20 settlement = IERC20(settlementsCurrency);
                        settlement.transfer(orderList[i].owner,orderList[i].settlementsAmount);           
                    }           

                }
            }
        }
         if (index < orderList.length) {
            orderList.length = index;
        }

    }
    function _removeEmptySellOrder(address optionsToken,address settlementsCurrency)internal{
        SellOptionsOrder[] storage orderList = sellOrderMap[settlementsCurrency][optionsToken];
        uint256 index = 0;
        for (uint i=0;i<orderList.length;i++) {
            if (orderList[i].amount > 0) {
                if(i != index) {
                    sellOrderMap[settlementsCurrency][optionsToken][index].owner = orderList[i].owner;
                    sellOrderMap[settlementsCurrency][optionsToken][index].createdTime = orderList[i].createdTime;
                    sellOrderMap[settlementsCurrency][optionsToken][index].amount = orderList[i].amount;
                }
                index++;
            }
        }
        if (index < orderList.length) {
            sellOrderMap[settlementsCurrency][optionsToken].length = index;
        }
    }
    function _calPayment(uint256 amount,uint256 optionsPrice,uint256 currencyPrice) internal view returns (uint256,uint256) {
        uint256 optionsPay = optionsPrice.mul(amount).div(currencyPrice);
        uint256 transFee = _calNumberMulUint(transactionFee,optionsPay);
        optionsPay = optionsPay.sub(transFee);
        transFee = transFee.mul(2);
        return (transFee, optionsPay);
    }

}