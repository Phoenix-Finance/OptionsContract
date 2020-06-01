pragma solidity ^0.4.26;
import "./TransactionFee.sol";
import "./CompoundOracleInterface.sol";
import "./SafeMath.sol";
import "./IERC20.sol";
import "./IOptionsManager.sol";
contract MatchMakingTrading is TransactionFee {
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
    uint256 private _tradingEnd = 5 hours;
    IOptionsManager private _optionsManager;
    ICompoundOracle private _oracle;
    //mapping settlementsCurrency => OptionsToken => OptionsOrder
    mapping(address => mapping(address => PayOptionsOrder[])) public payOrderMap;
    mapping(address => mapping(address => SellOptionsOrder[])) public sellOrderMap;

    event AddPayOrder(address indexed from,address indexed optionsToken,address indexed settlementsCurrency,uint256 amount, uint256 settlementsAmount);
    event AddSellOrder(address indexed from,address indexed optionsToken,address indexed settlementsCurrency,uint256 amount);
    event SellOptionsToken(address indexed from,address indexed optionsToken,address indexed settlementsCurrency,uint256 amount);
    event ReturnExpiredOrders(address indexed optionsToken);
    event BuyOptionsToken(address indexed from,address indexed optionsToken,address indexed settlementsCurrency,uint256 amount);
    event RedeemPayOrder(address indexed from,address indexed optionsToken,address indexed settlementsCurrency,uint256 amount);
    event RedeemSellOrder(address indexed from,address indexed optionsToken,address indexed settlementsCurrency,uint256 amount);
    event DebugEvent(uint256 value0,uint256 value1,uint256 value2);
    //*******************getter***********************
    function getOracleAddress() public view returns(address){
        return address(_oracle);
    }
    function getOptionsManagerAddress() public view returns(address){
        return address(_optionsManager);
    }
    function getTradingEnd() public view returns(uint256){
        return _tradingEnd;
    }
    function getPayOrderList(address OptionsToken,address settlementsCurrency) public view returns(address[],uint256[],uint256[],uint256[]){
        PayOptionsOrder[] storage payOrders = payOrderMap[settlementsCurrency][OptionsToken];
        address[] memory owners = new address[](payOrders.length);
        uint256[] memory times = new uint256[](payOrders.length);
        uint256[] memory amounts = new uint256[](payOrders.length);
        uint256[] memory settlements = new uint256[](payOrders.length);
        for (uint i=0;i<payOrders.length;i++){
            owners[i] = payOrders[i].owner;
            times[i] = payOrders[i].createdTime;
            amounts[i] = payOrders[i].amount;
            settlements[i] = payOrders[i].settlementsAmount;
        }
        return (owners,times,amounts,settlements);
    }
    function getSellOrderList(address OptionsToken,address settlementsCurrency) public view returns(address[],uint256[],uint256[]){
         SellOptionsOrder[] storage sellOrders = sellOrderMap[settlementsCurrency][OptionsToken];
        address[] memory owners = new address[](sellOrders.length);
        uint256[] memory times = new uint256[](sellOrders.length);
        uint256[] memory amounts = new uint256[](sellOrders.length);
        for (uint i=0;i<sellOrders.length;i++){
            owners[i] = sellOrders[i].owner;
            times[i] = sellOrders[i].createdTime;
            amounts[i] = sellOrders[i].amount;
        }
        return (owners,times,amounts);
    }
    //*******************setter***********************
    function setOracleAddress(address oracle)public onlyOwner{
        _oracle = ICompoundOracle(oracle);
    }
    function setOptionsManagerAddress(address optionsManager)public onlyOwner{
        _optionsManager = IOptionsManager(optionsManager);
    }
    function setTradingEnd(uint256 tradingEnd) public onlyOwner {
        _tradingEnd = tradingEnd;
    }
    function addPayOrder(address optionsToken,address settlementsCurrency,uint256 deposit,uint256 buyAmount) public payable{
        require(isEligibleAddress(settlementsCurrency),"This settlements currency is ineligible");
        require(isEligibleOptionsToken(optionsToken),"This options token is ineligible");
        uint256 tokenPrice = _oracle.getBuyOptionsPrice(optionsToken);
        uint256 currencyPrice = _oracle.getPrice(settlementsCurrency);
        var (optionsPay,transFee) = _calPayment(buyAmount,tokenPrice,currencyPrice);
        uint256 settlements = deposit;
        if (settlementsCurrency == address(0)){
            settlements = msg.value;
        }else{
            IERC20 settlement = IERC20(settlementsCurrency);
            settlement.transferFrom(msg.sender,address(this),settlements);           
        }
        require(optionsPay.add(transFee)<=settlements,"settlements Currency is insufficient!");
        payOrderMap[settlementsCurrency][optionsToken].push(PayOptionsOrder(msg.sender,now,buyAmount,settlements));
        emit AddPayOrder(msg.sender,optionsToken,settlementsCurrency,buyAmount,settlements);
    }
    function addSellOrder(address optionsToken,address settlementsCurrency,uint256 amount) public {
        require(isEligibleAddress(settlementsCurrency),"This settlements currency is ineligible");
        require(isEligibleOptionsToken(optionsToken),"This options token is ineligible");
        IERC20 ERC20Token = IERC20(optionsToken);
        ERC20Token.transferFrom(msg.sender,address(this),amount);  
        sellOrderMap[settlementsCurrency][optionsToken].push(SellOptionsOrder(msg.sender,now,amount));
        emit AddSellOrder(msg.sender,optionsToken,settlementsCurrency,amount);
    }
    function redeemPayOrder(address optionsToken,address settlementsCurrency) public{
        require(isEligibleAddress(settlementsCurrency),"This settlements currency is ineligible");
        require(isEligibleOptionsToken(optionsToken),"This options token is ineligible");
        PayOptionsOrder[] storage orderList = payOrderMap[settlementsCurrency][optionsToken];
        for (uint256 i=0;i<orderList.length;i++){
            if (orderList[i].owner == msg.sender){
                uint256 payAmount = orderList[i].settlementsAmount;
                if (orderList[i].settlementsAmount > 0){
                    orderList[i].settlementsAmount = 0;
                    if (settlementsCurrency == address(0)) {
                        orderList[i].owner.transfer(payAmount);                
                    }else {
                        IERC20 settlement = IERC20(settlementsCurrency);
                        settlement.transfer(orderList[i].owner,payAmount);           
                    }
                }
                emit RedeemPayOrder(msg.sender,optionsToken,settlementsCurrency,orderList[i].amount);
                for (uint256 j=i+1;j<orderList.length;j++) {
                    orderList[i].owner = orderList[j].owner;
                    orderList[i].createdTime = orderList[j].createdTime;
                    orderList[i].amount = orderList[j].amount;
                    orderList[i].settlementsAmount = orderList[j].settlementsAmount;
                    i++;
                }
                orderList.length--;
                break;
            }
        }

    }
    function redeemSellOrder(address optionsToken,address settlementsCurrency) public {
        require(isEligibleAddress(settlementsCurrency),"This settlements currency is ineligible");
        require(isEligibleOptionsToken(optionsToken),"This options token is ineligible");
        SellOptionsOrder[] storage orderList = sellOrderMap[settlementsCurrency][optionsToken];
        for (uint256 i=0;i<orderList.length;i++){
            if (orderList[i].owner == msg.sender){
                uint256 payAmount = orderList[i].amount;
                if (orderList[i].amount > 0){
                    orderList[i].amount = 0;
                    IERC20 options = IERC20(optionsToken);
                    options.transfer(orderList[i].owner,payAmount);           
                }
                emit RedeemSellOrder(msg.sender,optionsToken,settlementsCurrency,payAmount);
                for (uint256 j=i+1;j<orderList.length;j++) {
                    orderList[i].owner = orderList[j].owner;
                    orderList[i].createdTime = orderList[j].createdTime;
                    orderList[i].amount = orderList[j].amount;
                    i++;
                }
                orderList.length--;
                break;
            }
        }
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
        require(allPay.add(transFee)<=currencyAmount,"pay value is insufficient!");
        uint256 _totalBuy = 0;
        SellOptionsOrder[] storage orderList = sellOrderMap[settlementsCurrency][optionsToken];
        for (uint256 i=0;i<orderList.length;i++) {
            uint256 optionsAmount = amount;
            if (amount > orderList[i].amount) {
                optionsAmount = orderList[i].amount;
            }
            amount = amount.sub(optionsAmount);
            _totalBuy = _totalBuy.add(optionsAmount);
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
        emit BuyOptionsToken(msg.sender,optionsToken,settlementsCurrency,_totalBuy);
        _removeEmptySellOrder(optionsToken,settlementsCurrency);
    }
    function sellOptionsToken(address optionsToken,uint256 amount,address settlementsCurrency) public {
        uint256 tokenPrice = _oracle.getSellOptionsPrice(optionsToken);
        uint256 currencyPrice = _oracle.getPrice(settlementsCurrency);
        uint256 _totalSell = 0;
        IERC20 erc20Token = IERC20(optionsToken);
        erc20Token.transferFrom(msg.sender,address(this),amount);
        PayOptionsOrder[] storage orderList = payOrderMap[settlementsCurrency][optionsToken];
        for (uint256 i=0;i<orderList.length;i++){
            if (!_isSufficientSettlements(orderList[i],tokenPrice,currencyPrice)){
                continue;
            }
            uint256 optionsAmount = amount;
            if (optionsAmount > orderList[i].amount) {
                optionsAmount = orderList[i].amount;
            }

            amount = amount.sub(optionsAmount);
            _totalSell = _totalSell.add(optionsAmount);
            emit DebugEvent(2,amount,_totalSell);
            uint256 sellAmount = 0;
            uint256 leftCurrency = 0;
            (sellAmount,leftCurrency) = _orderTrading(optionsToken,optionsAmount,tokenPrice,settlementsCurrency,orderList[i].settlementsAmount,currencyPrice,
            msg.sender,orderList[i].owner);
            emit DebugEvent(3,sellAmount,leftCurrency);
            orderList[i].amount = orderList[i].amount.sub(sellAmount);
            orderList[i].settlementsAmount = leftCurrency;
            emit DebugEvent(4,orderList[i].amount,orderList[i].settlementsAmount);
            if (amount == 0) {
                break;
            }
        }
        if (amount > 0){
            erc20Token.transfer(msg.sender,amount);
        }
        emit SellOptionsToken(msg.sender,optionsToken,settlementsCurrency,_totalSell);
        _removeEmptyPayOrder(optionsToken,settlementsCurrency);
    }
    function returnExpiredOrders()public{
        address[] memory options = _optionsManager.getOptionsTokenList();
        for (uint256 i=0;i<options.length;i++){
            if (!isEligibleAddress(options[i])){
                for (uint j=0;j<whiteList.length;j++){
                    _returnExpiredSellOrders(options[i],whiteList[j]);
                    _returnExpiredPayOrders(options[i],whiteList[j]);
                }
                emit ReturnExpiredOrders(options[i]);
            }
        }
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
                    orderList[index].owner = orderList[i].owner;
                    orderList[index].createdTime = orderList[i].createdTime;
                    orderList[index].amount = orderList[i].amount;
                    orderList[index].settlementsAmount = orderList[i].settlementsAmount;
                }
                index++;
            }else {
                if (orderList[i].settlementsAmount > 0) {
                    uint256 payAmount = orderList[i].settlementsAmount;
                    orderList[i].settlementsAmount = 0;
                    if (settlementsCurrency == address(0)) {
                        orderList[i].owner.transfer(payAmount);                
                    }else {
                        IERC20 settlement = IERC20(settlementsCurrency);
                        settlement.transfer(orderList[i].owner,payAmount);           
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
                    orderList[index].owner = orderList[i].owner;
                    orderList[index].createdTime = orderList[i].createdTime;
                    orderList[index].amount = orderList[i].amount;
                }
                index++;
            }
        }
        if (index < orderList.length) {
            orderList.length = index;
        }
    }
    function _isSufficientSettlements(PayOptionsOrder storage payOrder,uint256 optionsPrice,uint256 currencyPrice) internal view returns(bool){
        uint256 allPay = 0;
        uint256 transFee = 0;
        (allPay,transFee) = _calPayment(payOrder.amount,optionsPrice,currencyPrice);
        if (allPay.add(transFee) > payOrder.settlementsAmount){
            return false;
        }
        return true;
    }
    function _calPayment(uint256 amount,uint256 optionsPrice,uint256 currencyPrice) internal view returns (uint256,uint256) {
        uint256 optionsPay = optionsPrice.mul(amount).div(currencyPrice);
        uint256 transFee = _calNumberMulUint(transactionFee,optionsPay);
        optionsPay = optionsPay.sub(transFee);
        transFee = transFee.mul(2);
        return (optionsPay,transFee);
    }
    function _returnExpiredSellOrders(address optionsToken,address settlementsCurrency) internal {
        IERC20 options = IERC20(optionsToken);
        SellOptionsOrder[] storage orderList = sellOrderMap[settlementsCurrency][optionsToken];
        for (uint i=0;i<orderList.length;i++) {
            if (orderList[i].amount > 0) {
                uint256 payAmount = orderList[i].amount;
                orderList[i].amount = 0;
                options.transfer(orderList[i].owner,payAmount);
            }
        }
        delete sellOrderMap[settlementsCurrency][optionsToken];
    }
    function _returnExpiredPayOrders(address optionsToken,address settlementsCurrency) internal{
        PayOptionsOrder[] storage orderList = payOrderMap[settlementsCurrency][optionsToken];
        for (uint i=0;i<orderList.length;i++) {
            if (orderList[i].settlementsAmount > 0) {
                uint256 payAmount = orderList[i].settlementsAmount;
                orderList[i].settlementsAmount = 0;
                if (settlementsCurrency == address(0)) {
                    orderList[i].owner.transfer(payAmount);                
                }else {
                    IERC20 settlement = IERC20(settlementsCurrency);
                    settlement.transfer(orderList[i].owner,payAmount);           
                }   
             }
        }
        delete payOrderMap[settlementsCurrency][optionsToken];
    }
    function isEligibleOptionsToken(address optionsToken) public view returns(bool) {
        var (,,,,expiration,exercised) = _optionsManager.getOptionsTokenInfo(optionsToken);
        uint256 tradingEnd = _tradingEnd.add(now);
        return tradingEnd < expiration;
        return !exercised;
        return (expiration > 0 && tradingEnd < expiration && !exercised);
    }
}