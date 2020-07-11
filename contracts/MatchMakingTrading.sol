pragma solidity ^0.4.26;
import "./TransactionFee.sol";
import "./ReentrancyGuard.sol";
import "./CompoundOracleInterface.sol";
import "./SafeMath.sol";
import "./IERC20.sol";
import "./IOptionsManager.sol";
contract MatchMakingTrading is TransactionFee,ReentrancyGuard {
    using SafeMath for uint256;
    //sell options order defination
    struct SellOptionsOrder {
        address owner;
        uint256 createdTime;
        uint256 amount;
    }
    //pay options order defination
    struct PayOptionsOrder {
        address owner;
        uint256 createdTime;
        uint256 amount;
        uint256 settlementsAmount;
    }
    //_tradingEnd is a deadline of a options token trading. All orders can trade before optionsToken's expiration-tradingEnd. After that time,
    //all Orders will be retrurned back to the owner.
    uint256 private _tradingEnd = 5 hours;
    //options manager interface;
    IOptionsManager private _optionsManager;
    //oracle interface.
    ICompoundOracle private _oracle;
    //mapping settlementCurrency => OptionsToken => OptionsOrder
    mapping(address => mapping(address => PayOptionsOrder[])) public payOrderMap;
    mapping(address => mapping(address => SellOptionsOrder[])) public sellOrderMap;

    event AddPayOrder(address indexed from,address indexed optionsToken,address indexed settlementCurrency,uint256 amount, uint256 settlementsAmount);
    event AddSellOrder(address indexed from,address indexed optionsToken,address indexed settlementCurrency,uint256 amount);
    event SellOptionsToken(address indexed from,address indexed optionsToken,address indexed settlementCurrency,uint256 optionsPrice,uint256 amount,uint256 payback);
    event BuyOptionsToken(address indexed from,address indexed optionsToken,address indexed settlementCurrency,uint256 optionsPrice,uint256 amount,uint256 totalPay);
    event OrderSellerPayback(address indexed optionsToken,address indexed seller,address indexed settlementCurrency,uint256 payback);
    event OrderBuyerPayback(address indexed optionsToken,address indexed buyer,uint256 amount);
    event ReturnExpiredOrders(address indexed optionsToken);
    event RedeemPayOrder(address indexed from,address indexed optionsToken,address indexed settlementCurrency,uint256 amount, uint256 settlementsAmount);
    event RedeemSellOrder(address indexed from,address indexed optionsToken,address indexed settlementCurrency,uint256 amount);
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
    /**
      * @dev getting all of the pay orders;
      * @param optionsToken options token address
      * @param settlementCurrency the settlement currency address
      * @return owner account, created time, buy amount, settlements deposition.
      */
    function getPayOrderList(address optionsToken,address settlementCurrency) public view returns(address[],uint256[],uint256[],uint256[]){
        PayOptionsOrder[] storage payOrders = payOrderMap[settlementCurrency][optionsToken];
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
    /**
      * @dev getting all of the sell orders;
      * @param optionsToken options token address
      * @param settlementCurrency the settlement currency address
      * @return owner account, created time, sell amount.
      */
    function getSellOrderList(address optionsToken,address settlementCurrency) public view returns(address[],uint256[],uint256[]){
         SellOptionsOrder[] storage sellOrders = sellOrderMap[settlementCurrency][optionsToken];
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
    /**
      * @dev add a pay order, if your deposition is insufficient, your order will be disable.
      * @param optionsToken options token address
      * @param settlementCurrency the settlement currency address
      * @param deposit you need to deposit some settlement currency to pay the order.deposit is the amount of settlement currency to pay.
      * @param buyAmount the options token amount you want to buy.
      */
    function addPayOrder(address optionsToken,address settlementCurrency,uint256 deposit,uint256 buyAmount)
         nonReentrant notHalted nonContract public payable{
        require(isEligibleAddress(settlementCurrency),"This settlements currency is ineligible");
        require(isEligibleOptionsToken(optionsToken),"This options token is ineligible");
        uint256 tokenPrice = _oracle.getSellOptionsPrice(optionsToken);
        uint256 currencyPrice = _oracle.getPrice(settlementCurrency);
        (uint256 optionsPay, uint256 transFee) = _calPayment(buyAmount,tokenPrice,currencyPrice);
        uint256 settlements = deposit;
        if (settlementCurrency == address(0)){
            settlements = msg.value;
        }else{
            IERC20 settlement = IERC20(settlementCurrency);
            settlement.transferFrom(msg.sender,address(this),settlements);           
        }
        require(optionsPay.add(transFee)<=settlements,"settlements Currency is insufficient!");
        payOrderMap[settlementCurrency][optionsToken].push(PayOptionsOrder(msg.sender,now,buyAmount,settlements));
        emit AddPayOrder(msg.sender,optionsToken,settlementCurrency,buyAmount,settlements);
    }
    /**
      * @dev add a sell order. The Amount of options token will be transfered into contract address.
      * @param optionsToken options token address
      * @param settlementCurrency the settlement currency address
      * @param amount the options token amount you want to sell.
      */
    function addSellOrder(address optionsToken,address settlementCurrency,uint256 amount)
        nonReentrant notHalted nonContract public {
        require(isEligibleAddress(settlementCurrency),"This settlements currency is ineligible");
        require(isEligibleOptionsToken(optionsToken),"This options token is ineligible");
        IERC20 ERC20Token = IERC20(optionsToken);
        ERC20Token.transferFrom(msg.sender,address(this),amount);  
        sellOrderMap[settlementCurrency][optionsToken].push(SellOptionsOrder(msg.sender,now,amount));
        emit AddSellOrder(msg.sender,optionsToken,settlementCurrency,amount);
    }
    /**
      * @dev redeem a pay order.redeem the earliest pay order.return back the deposition.
      * @param optionsToken options token address
      * @param settlementCurrency the settlement currency address
      */    
    function redeemPayOrder(address optionsToken,address settlementCurrency)
        nonReentrant notHalted public{
        require(isEligibleAddress(settlementCurrency),"This settlements currency is ineligible");
        require(isEligibleOptionsToken(optionsToken),"This options token is ineligible");
        PayOptionsOrder[] storage orderList = payOrderMap[settlementCurrency][optionsToken];
        for (uint256 i=0;i<orderList.length;i++){
            if (orderList[i].owner == msg.sender){
                _redeemBuyOrder(optionsToken,settlementCurrency,orderList,i);
                break;
            }
        }
    }
        /**
      * @dev redeem all invalid pay order.redeem all insufficient pay orders.return back the deposition.
      * @param optionsToken options token address
      * @param settlementCurrency the settlement currency address
      */    
    function redeemInvalidPayOrder(address optionsToken,address settlementCurrency)
        nonReentrant notHalted public{
        require(isEligibleAddress(settlementCurrency),"This settlements currency is ineligible");
        require(isEligibleOptionsToken(optionsToken),"This options token is ineligible");
        uint256 tokenPrice = _oracle.getSellOptionsPrice(optionsToken);
        uint256 currencyPrice = _oracle.getPrice(settlementCurrency);
        PayOptionsOrder[] storage orderList = payOrderMap[settlementCurrency][optionsToken];
        for (uint256 i=0;i<orderList.length;i++){
            if (!gasSufficient()){
                return;
            }
            if (orderList[i].owner == msg.sender){
                if (!_isSufficientSettlements(orderList[i],tokenPrice,currencyPrice)){
                    _redeemBuyOrder(optionsToken,settlementCurrency,orderList,i);
                    i--;
                }
            }
        }

    }
    /**
      * @dev redeem a sell order.redeem the earliest sell order.return back the options token.
      * @param optionsToken options token address
      * @param settlementCurrency the settlement currency address
      */    
    function redeemSellOrder(address optionsToken,address settlementCurrency)
        nonReentrant notHalted public {
        require(isEligibleAddress(settlementCurrency),"This settlements currency is ineligible");
        require(isEligibleOptionsToken(optionsToken),"This options token is ineligible");
        SellOptionsOrder[] storage orderList = sellOrderMap[settlementCurrency][optionsToken];
        for (uint256 i=0;i<orderList.length;i++){
            if (orderList[i].owner == msg.sender){
                uint256 tokenAmount = orderList[i].amount;
                if (orderList[i].amount > 0){
                    orderList[i].amount = 0;
                    IERC20 options = IERC20(optionsToken);
                    options.transfer(orderList[i].owner,tokenAmount);
                }
                emit RedeemSellOrder(msg.sender,optionsToken,settlementCurrency,tokenAmount);
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
    /**
      * @dev buy amount options token form sell order.
      * @param optionsToken options token address
      * @param amount options token amount you want to buy
      * @param settlementCurrency the settlement currency address
      * @param currencyAmount the settlement currency amount will be payed for
      */     
    function buyOptionsToken(address optionsToken,uint256 amount,address settlementCurrency,uint256 currencyAmount)
        nonReentrant notHalted nonContract public payable {
        uint256 tokenPrice = _oracle.getBuyOptionsPrice(optionsToken);
        uint256 currencyPrice = _oracle.getPrice(settlementCurrency);
        IERC20 settlement = IERC20(settlementCurrency);
        if (settlementCurrency == address (0)) {
            currencyAmount = msg.value;
        }else{
            settlement.transferFrom(msg.sender,address(this),currencyAmount);      
        }
        uint256 totalSetterment = currencyAmount;
        (uint256 allSell,uint256 transFee) = _calPayment(amount,tokenPrice,currencyPrice);
        require(allSell.add(transFee)<=currencyAmount,"pay value is insufficient!");
        allSell = 0;//all sell amount
        SellOptionsOrder[] storage orderList = sellOrderMap[settlementCurrency][optionsToken];
        for (uint256 i=0;i<orderList.length;i++) {
            uint256 optionsAmount = amount;
            if (amount > orderList[i].amount) {
                optionsAmount = orderList[i].amount;
            }
            uint256 sellAmount = 0;
            (sellAmount,currencyAmount) = _orderTrading(optionsToken,optionsAmount,tokenPrice,settlementCurrency,currencyAmount,currencyPrice,
                        orderList[i].owner,msg.sender);
            amount = amount.sub(sellAmount);
            allSell = allSell.add(sellAmount);

            orderList[i].amount = orderList[i].amount.sub(sellAmount);
            if (amount == 0) {
                break;
            }
        }
        _transferPayback(msg.sender,settlementCurrency,currencyAmount);
        totalSetterment = totalSetterment.sub(currencyAmount);
        emit BuyOptionsToken(msg.sender,optionsToken,settlementCurrency,tokenPrice,allSell,totalSetterment);
        _removeEmptySellOrder(optionsToken,settlementCurrency);
    }
    /**
      * @dev sell amount options token to buy order.
      * @param optionsToken options token address
      * @param amount options token amount you want to sell
      * @param settlementCurrency the settlement currency address
      */      
    function sellOptionsToken(address optionsToken,uint256 amount,address settlementCurrency)
        nonReentrant notHalted nonContract public {
        uint256 tokenPrice = _oracle.getSellOptionsPrice(optionsToken);
        uint256 currencyPrice = _oracle.getPrice(settlementCurrency);
        uint256 _totalSell = 0;
        uint256 _totalPayback = 0;
        IERC20 erc20Token = IERC20(optionsToken);
        erc20Token.transferFrom(msg.sender,address(this),amount);
        PayOptionsOrder[] storage orderList = payOrderMap[settlementCurrency][optionsToken];
        for (uint256 i=0;i<orderList.length;i++){
            if (!_isSufficientSettlements(orderList[i],tokenPrice,currencyPrice)){
                continue;
            }
            uint256 optionsAmount = amount;
            if (optionsAmount > orderList[i].amount) {
                optionsAmount = orderList[i].amount;
            }
            (uint256 sellAmount,uint256 leftCurrency) = _orderTrading(optionsToken,optionsAmount,tokenPrice,settlementCurrency,orderList[i].settlementsAmount,currencyPrice,
            msg.sender,orderList[i].owner);
            _totalSell = _totalSell.add(sellAmount);
            amount = amount.sub(sellAmount);  
            orderList[i].amount = orderList[i].amount.sub(sellAmount);
            _totalPayback = _totalPayback.add(orderList[i].settlementsAmount.sub(leftCurrency));
            orderList[i].settlementsAmount = leftCurrency;
            if (amount == 0) {
                break;
            }
        }
        if (amount > 0){
            erc20Token.transfer(msg.sender,amount);
        }
        emit SellOptionsToken(msg.sender,optionsToken,settlementCurrency,tokenPrice,_totalSell,_totalPayback);
        _removeEmptyPayOrder(optionsToken,settlementCurrency);
    }
    /**
      * @dev return back the expired options token orders. Both buy orders and sell orders
      */        
    function returnExpiredOrders()
        nonReentrant notHalted public{
        address[] memory options = _optionsManager.getOptionsTokenList();
        for (uint256 i=0;i<options.length;i++){
            if (!isEligibleOptionsToken(options[i])){
                for (uint j=0;j<whiteList.length;j++){
                    if (!gasSufficient()) {
                        return;
                    }
                    _returnExpiredSellOrders(options[i],whiteList[j]);
                    if (!gasSufficient()) {
                        return;
                    }
                    _returnExpiredPayOrders(options[i],whiteList[j]);
                }
                emit ReturnExpiredOrders(options[i]);
            }
        }
    }
    function gasSufficient()internal returns(bool){
        return gasleft()>1000000;
    }
    function _redeemBuyOrder(address optionToken,address settlementCurrency,PayOptionsOrder[] storage orderList,uint256 i) private {
        _returnPayOrders(orderList[i],settlementCurrency);
        emit RedeemPayOrder(msg.sender,optionToken,settlementCurrency,orderList[i].amount,orderList[i].settlementsAmount);
        for (uint256 j=i+1;j<orderList.length;j++) {
            orderList[i].owner = orderList[j].owner;
            orderList[i].createdTime = orderList[j].createdTime;
            orderList[i].amount = orderList[j].amount;
            orderList[i].settlementsAmount = orderList[j].settlementsAmount;
            i++;
        }
        orderList.length--;
    }
    function _orderTrading(address optionsToken,uint256 amount,uint256 optionsPrice,
            address settlementCurrency,uint256 currencyAmount,uint256 currencyPrice,
            address seller,address buyer) internal returns (uint256,uint256) {
        (uint256 optionsPay,uint256 transFee) = _calPayment(amount,optionsPrice,currencyPrice);
        if (optionsPay.add(transFee)>currencyAmount){
            return (0,currencyAmount);
        }
        IERC20 erc20Token = IERC20(optionsToken);
        erc20Token.transfer(buyer,amount);
        _transferPayback(seller,settlementCurrency,optionsPay); 
        emit OrderSellerPayback(optionsToken,seller,settlementCurrency,optionsPay);
        optionsPay = optionsPay.add(transFee);
        currencyAmount = currencyAmount.sub(optionsPay);
        _addTransactionFee(settlementCurrency,transFee);
        emit OrderBuyerPayback(optionsToken,buyer,amount);
        return (amount,currencyAmount);
    }
    function _removeEmptyPayOrder(address optionsToken,address settlementCurrency)internal{
        PayOptionsOrder[] storage orderList = payOrderMap[settlementCurrency][optionsToken];
        uint256 index = 0;
        for (uint i=0;i<orderList.length;i++) {
            if (!gasSufficient()){
                return;
            }
            if (orderList[i].amount > 0) {
                if(i != index) {
                    orderList[index].owner = orderList[i].owner;
                    orderList[index].createdTime = orderList[i].createdTime;
                    orderList[index].amount = orderList[i].amount;
                    orderList[index].settlementsAmount = orderList[i].settlementsAmount;
                }
                index++;
            }else {
                _returnPayOrders(orderList[i],settlementCurrency);
            }
        }
         if (index < orderList.length) {
            orderList.length = index;
        }

    }
    function _removeEmptySellOrder(address optionsToken,address settlementCurrency)internal{
        SellOptionsOrder[] storage orderList = sellOrderMap[settlementCurrency][optionsToken];
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
        (uint256 allPay,uint256 transFee) = _calPayment(payOrder.amount,optionsPrice,currencyPrice);
        if (allPay.add(transFee) > payOrder.settlementsAmount){
            return false;
        }
        return true;
    }
    function _calPayment(uint256 amount,uint256 optionsPrice,uint256 currencyPrice) internal view returns (uint256,uint256) {
        uint256 allPayment = optionsPrice.mul(amount);
        uint256 optionsPay = allPayment.div(currencyPrice);
        uint256 transFee = _calNumberMulUint(transactionFee,optionsPay);
        optionsPay = optionsPay.sub(transFee);
        transFee = transFee.mul(2);
        return (optionsPay,transFee);
    }
    function _returnExpiredSellOrders(address optionsToken,address settlementCurrency) internal {
        IERC20 options = IERC20(optionsToken);
        SellOptionsOrder[] storage orderList = sellOrderMap[settlementCurrency][optionsToken];
        for (uint i=0;i<orderList.length;i++) {
               if (!gasSufficient()){
                    return;
                }
            if (orderList[i].amount > 0) {
                uint256 tokenAmount = orderList[i].amount;
                orderList[i].amount = 0;
                options.transfer(orderList[i].owner,tokenAmount);
            }
        }
        delete sellOrderMap[settlementCurrency][optionsToken];
    }
    function _returnExpiredPayOrders(address optionsToken,address settlementCurrency) internal{
        PayOptionsOrder[] storage orderList = payOrderMap[settlementCurrency][optionsToken];
        for (uint i=0;i<orderList.length;i++) {
                if (!gasSufficient()) {
                   return;
                }
            _returnPayOrders(orderList[i],settlementCurrency);
        }
        delete payOrderMap[settlementCurrency][optionsToken];
    }
    function _returnPayOrders(PayOptionsOrder storage payOrder,address settlementCurrency) internal {
    if (payOrder.settlementsAmount > 0) {
            uint256 payAmount = payOrder.settlementsAmount;
            payOrder.settlementsAmount = 0;
            _transferPayback(payOrder.owner,settlementCurrency,payAmount); 
        }
    }
    function isEligibleOptionsToken(address optionsToken) public view returns(bool) {
        (,,,,uint256 expiration,bool exercised) = _optionsManager.getOptionsTokenInfo(optionsToken);
        uint256 tradingEnd = _tradingEnd.add(now);
        return (expiration > 0 && tradingEnd < expiration && !exercised);
    }
}