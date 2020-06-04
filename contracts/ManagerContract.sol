pragma solidity ^0.4.26;
import "./SafeMath.sol";
import "./Ownable.sol";
import "./OptionsToken.sol";
import "./CompoundOracleInterface.sol";
import "./OptionsFormulas.sol";
import "./TransactionFee.sol";
contract OptionsVault is TransactionFee
{
    using SafeMath for uint256;
    enum OptionsType{
        OptCall,
        OptPut
    }
    struct OptionsInfo{
        OptionsType	optType;
        //Collateral currency address. If this address equals 0, it means that it is Eth;
        address		collateralCurrency;
        //underlying assets type;
        uint32		underlyingAssets;
        uint256		expiration;
        uint256      strikePrice;
        bool        isExercised;
    }
    // Keeps track of the OptionsWriter Info
    struct OptionsWriter {
        //Options wrter address;
        address		writer;
        //collateral amount.
        uint256		collateralAmount;
        //mint optionsToken amount
        uint256     OptionsTokenAmount;

    }
    struct IndexValue
    {
        uint keyIndex;
        OptionsInfo options;
        OptionsWriter[] writers;
    }
    struct KeyFlag { address key; bool deleted; }
    mapping(address => IndexValue) internal optionsMap;
    KeyFlag[] internal optionsTokenList;
    uint internal size = 0;
    function _insert(address key, 
                OptionsType optType,
                address collateral,
                uint32 underlyingAssets,
                uint256 expiration,
                uint256 strikePriceValue) internal returns (bool replaced)
    {
        uint keyIndex = optionsMap[key].keyIndex;
        optionsMap[key].options.optType = optType;
        optionsMap[key].options.collateralCurrency = collateral;
        optionsMap[key].options.underlyingAssets = underlyingAssets;
        optionsMap[key].options.expiration = expiration;
        optionsMap[key].options.strikePrice = strikePriceValue;
        optionsMap[key].options.isExercised = false;
        if (keyIndex > 0)
            return true;
        else
        {
            keyIndex = optionsTokenList.length++;
            optionsMap[key].keyIndex = keyIndex + 1;
            optionsTokenList[keyIndex].key = key;
            size++;
            return false;
        }
    }
    function _insertWriter( address key, uint256 amount,uint256 mintOptTokenAmount) internal returns (bool){
        OptionsWriter[] storage writers = optionsMap[key].writers;
        for (uint256 i=0;i<writers.length;i++ ){
            if (writers[i].writer == msg.sender){
                break;
            }
        }
        if (i == writers.length){
            optionsMap[key].writers.push(OptionsWriter(msg.sender,amount,mintOptTokenAmount));
        }else{
            optionsMap[key].writers[i].collateralAmount = optionsMap[key].writers[i].collateralAmount.add(amount);
            optionsMap[key].writers[i].OptionsTokenAmount = optionsMap[key].writers[i].OptionsTokenAmount.add(mintOptTokenAmount);
        }
        return true;
    }
    function _remove(address key) internal returns (bool)
    {
        uint keyIndex = optionsMap[key].keyIndex;
        if (keyIndex == 0)
            return false;
        delete optionsMap[key];
        optionsTokenList[keyIndex - 1].deleted = true;
        size --;
        return true;
    }
    function _contains(address key) internal view returns (bool)
    {
        return optionsMap[key].keyIndex > 0;
    }
    function _iterate_start() internal view returns (uint)
    {
        return _iterate_next(uint(-1));
    }
    function _iterate_valid(uint keyIndex) internal view returns (bool)
    {
        return keyIndex < optionsTokenList.length;
    }
    function _iterate_next( uint keyIndex) internal view returns (uint)
    {
        keyIndex++;
        while (keyIndex < optionsTokenList.length && optionsTokenList[keyIndex].deleted)
            keyIndex++;
        return keyIndex;
    }
    function getOptionsTokenList()public view returns (address[]){
        address[] memory optionsToken = new address[](size);
        uint256 index = 0;
        for(uint256 i=0;i<optionsTokenList.length;i++){
            if(!optionsTokenList[i].deleted){
                optionsToken[index] = optionsTokenList[i].key;
                index++;
            }
        }
        return optionsToken;
    }
    function getOptionsTokenWriterList(address tokenAddress)public view returns (address[],uint256[],uint256[]){
        if (_contains(tokenAddress)){
            OptionsWriter[] storage writers = optionsMap[tokenAddress].writers;
            address[] memory writerAddress = new address[](writers.length);
            uint256[] memory collateralAmount = new uint256[](writers.length);
            uint256[] memory OptionsTokenAmount = new uint256[](writers.length);
            for (uint256 i=0;i<writers.length;i++ ){
                writerAddress[i] = writers[i].writer;
                collateralAmount[i] = writers[i].collateralAmount;
                OptionsTokenAmount[i] = writers[i].OptionsTokenAmount;
            }            
            return (writerAddress,collateralAmount,OptionsTokenAmount);
        }
    }
    function getOptionsTokenInfo(address tokenAddress)public view returns (uint8,address,uint32,uint256,uint256,bool){
        if (_contains(tokenAddress)){
            OptionsInfo storage options = optionsMap[tokenAddress].options;
            return (uint8(options.optType),options.collateralCurrency,options.underlyingAssets,
                options.strikePrice,options.expiration,options.isExercised);
        }
    }
}
contract OptionsManager is OptionsVault {
    using SafeMath for uint256;
        constructor() public {
        
    }
    IOptFormulas internal _optionsFormulas;
    ICompoundOracle internal _oracle;
    uint256 private _calDecimal = 10000000000;
    // Number(2,-1) = 20%
    Number public liquidationIncentive = Number(2, -1);
    
    event CreateOptions (address indexed collateral,address indexed tokenAddress, uint32 indexed underlyingAssets,uint256 strikePrice,uint256 expiration,uint8 optType);
    event AddCollateral(address indexed optionsToken,uint256 indexed amount,uint256 mintOptionsTokenAmount);
    event WithdrawCollateral(address indexed optionsToken,uint256 amount);
    event Exercise(address indexed Sender,address indexed optionsToken);
    event Liquidate(address indexed Sender,address indexed optionsToken,address indexed writer,uint256 amount);
    event BurnOptionsToken(address indexed optionsToken,address indexed writer,uint256 amount);
    event DebugEvent(uint256 value0,uint256 value1,uint256 value2);




    //*******************getter***********************
    function getOracleAddress() public view returns(address){
        return address(_oracle);
    }
    function getFormulasAddress() public view returns(address){
        return address(_optionsFormulas);
    }
    function getLiquidationIncentive()public view returns (uint256,int32){
        return (liquidationIncentive.value,liquidationIncentive.exponent);
    }
    //*******************setter***********************
    function setOracleAddress(address oracle)public onlyOwner{
        _oracle = ICompoundOracle(oracle);
    }
    function setFormulasAddress(address formulas)public onlyOwner{
        _optionsFormulas = IOptFormulas(formulas);
    }
    function setLiquidationIncentive(uint256 value,int32 exponent)public onlyOwner{
        liquidationIncentive.value = value;
        liquidationIncentive.exponent = exponent;
    }
    /**
        * @dev  create an empty options token by owner;
        * @param optionsTokenName new migration options token name;
        * @param collateral The collateral asset
        * @param underlyingAssets underlying assets index, start at 1.
        * @param strikePrice The amount of strike asset that will be paid out per oToken
        * @param expiration The time at which the options expires
        * @param optType options type,0 is call options,1 is put options
        */
    function createOptionsToken(string optionsTokenName,address collateral,
    uint32 underlyingAssets,
    uint256 strikePrice,
    uint256 expiration,
    uint8 optType)
    public onlyOwner{
        require(underlyingAssets>0 , "underlying cannot be zero");
        require(isEligibleAddress(collateral) , "It is unsupported token");
        expiration = expiration.add(now);
        address newToken = new OptionsToken(expiration,optionsTokenName);
        assert(newToken != 0);
        _insert(newToken,OptionsType(optType),collateral,underlyingAssets,expiration,strikePrice);
        emit CreateOptions(collateral,newToken,underlyingAssets,strikePrice,expiration,optType);
        
    }
     /**
        * @dev  add Collateral. Any writer can add collateral to an exist options token,and mint options token;
        * @param optionsToken The Options token address.
        * @param collateral The collateral asset
        * @param amount The amount of collateral asset
        * @param mintOptionsTokenAmount The amount of options token will be minted and sent to the writer;
        */   
    function addCollateral(address optionsToken,address collateral,uint256 amount,uint256 mintOptionsTokenAmount)public payable{
        require(_contains(optionsToken),"This OptionsToken does not exist");
        require(!_isExpired(optionsMap[optionsToken]), "This OptionsToken expired");
        require(optionsMap[optionsToken].options.collateralCurrency == collateral,"Collateral currency type error");
        _mintOptionsToken(optionsToken,collateral,amount,mintOptionsTokenAmount);
        emit AddCollateral(optionsToken,amount,mintOptionsTokenAmount);
    }
     /**
        * @dev  Withdraw Collateral. Any writer can withdraw his collateral if his collateral assets are surplus;
        * @param optionsToken The Options token address.
        * @param amount The amount  collateral asset which will be Withdrawn
        */   
    function withdrawCollateral(address optionsToken,uint256 amount)public{
        require(_contains(optionsToken),"This OptionsToken does not exist");
        require(!_isExpired(optionsMap[optionsToken]), "This OptionsToken expired");
        OptionsWriter[] storage writers = optionsMap[optionsToken].writers;
        uint256 index = writers.length;
        for (uint256 i=0;i<writers.length;i++){
            if (writers[i].writer == msg.sender){
                index = i;
                break;
            }
        }
        if (index != writers.length){
            uint256 allCollateral = writers[index].collateralAmount.sub(amount);
            uint256 allMintToken = writers[index].OptionsTokenAmount;
            if (_isSufficientCollateral(optionsMap[optionsToken].options,allCollateral,allMintToken)){
                if (optionsMap[optionsToken].options.collateralCurrency == address (0)){
                    msg.sender.transfer(amount);
                }else{
                    IERC20 oToken = IERC20(optionsMap[optionsToken].options.collateralCurrency);
                    oToken.transfer(msg.sender,amount);
                }
                optionsMap[optionsToken].writers[index].collateralAmount = allCollateral;
                emit WithdrawCollateral(optionsToken,amount);
            }else{

            }
        }else{

        }
    }
    /**
      * @dev  exercise all of the expired options token;
      */  
    function exercise()public{
        for (uint keyIndex = _iterate_start();_iterate_valid(keyIndex);keyIndex = _iterate_next(keyIndex)){
            IndexValue storage optionsItem = optionsMap[optionsTokenList[keyIndex].key];
            _exercise(optionsTokenList[keyIndex].key,optionsItem);
        }
    }
    /**
      * @dev  liquidate if a writer's options collateral assets are insuficient;
      * @param optionsToken The Options token address.
      * @param writer The Options writer address.
      * @param amount The amount  of optionsToken which will be liquidated
      */  
    function liquidate(address optionsToken,address writer,uint256 amount)public{
        require(_contains(optionsToken),"This OptionsToken does not exist");
        IndexValue storage optionsItem = optionsMap[optionsToken];
        require(!_isExpired(optionsItem), "OptionsToken expired");
        for(uint256 i=0;i<optionsItem.writers.length;i++){
            if(optionsItem.writers[i].writer == writer){
                break;
            }
        }
        require(i != optionsItem.writers.length,"Option token writer is not exist");

        require(amount <= optionsItem.writers[i].OptionsTokenAmount,"liquidated token amount exceeds writter's mintToken amount");
        require(!_isSufficientCollateral(optionsItem.options,
            optionsItem.writers[i].collateralAmount,
            optionsItem.writers[i].OptionsTokenAmount),"option token writter' Collateral is sufficient");
        IERC20 optToken = IERC20(optionsToken);
        optToken.transferFrom(msg.sender, address(this), amount);
        uint256 tokenPrice = _oracle.getBuyOptionsPrice(optionsToken);
        uint256 _payback = tokenPrice.mul(amount);
        uint256 price = _oracle.getPrice(optionsItem.options.collateralCurrency);
        _payback = _payback.div(price);
        uint256 incentive = _calNumberMulUint(liquidationIncentive,_payback);
        emit DebugEvent(18,_payback,incentive);
        _payback = _payback.add(incentive);
        uint256 _transFee;
        (_payback,_transFee) = _calSufficientPayback(_payback,optionsItem.writers[i].collateralAmount);
        emit DebugEvent(19,_payback,_transFee);
        optionsItem.writers[i].collateralAmount = optionsItem.writers[i].collateralAmount.sub(_payback);
        optionsItem.writers[i].collateralAmount = optionsItem.writers[i].collateralAmount.sub(_transFee);
        _addTransactionFee(optionsItem.options.collateralCurrency,_transFee);
        optionsItem.writers[i].OptionsTokenAmount = optionsItem.writers[i].OptionsTokenAmount.sub(amount);
        //transfer
        _transferPayback(msg.sender,optionsItem.options.collateralCurrency,_payback);
        IIterableToken itoken = IIterableToken(optionsToken);
        itoken.burn(amount);
        emit Liquidate(msg.sender,optionsToken,writer,amount);
    }
    /**
      * @dev  A options writer burn some of his own token;
      * @param optionsToken The Options token address.
      * @param amount The amount of options token which will be burned
      */     
    function burnOptionsToken(address optionsToken,uint256 amount)public{
       require(_contains(optionsToken),"This OptionsToken does not exist");
        IndexValue storage optionsItem = optionsMap[optionsToken];
        require(!_isExpired(optionsItem), "OptionsToken expired");
        for(uint256 i=0;i<optionsItem.writers.length;i++){
            if(optionsItem.writers[i].writer == msg.sender){
                break;
            }
        }
        if (i != optionsItem.writers.length) {
            if( amount > optionsItem.writers[i].OptionsTokenAmount){
                return;
            }
            IERC20 optToken = IERC20(optionsToken);
            optToken.transferFrom(msg.sender, address(this), amount);
            optionsItem.writers[i].OptionsTokenAmount = optionsItem.writers[i].OptionsTokenAmount.sub(amount);
            //burn
            IIterableToken itoken = IIterableToken(optionsToken);
            itoken.burn(amount);
            emit BurnOptionsToken(optionsToken,msg.sender,amount);
        }
    }
    /**
      * @dev  exercise an options token;
      * @param tokenAddress The Options token address.
      * @param optionsItem The Options token information and writer information list.

      */  
    function _exercise(address tokenAddress,IndexValue storage optionsItem)internal {
        if (!_isExpired(optionsItem)  || _isExercised(optionsItem) || optionsItem.writers.length == 0) {
            return;
        }
        optionsItem.options.isExercised = true;
        //calculate tokenPayback
        uint256 tokenPayback = _calExerciseTokenPayback(optionsItem);
        emit DebugEvent(5,uint256(tokenAddress),tokenPayback);
         if (tokenPayback == 0 ){
            return;
        }
       //calculate balance pay back
        IIterableToken iterToken = IIterableToken(tokenAddress);
        
        for (uint keyIndex = iterToken.iterate_balance_start();
            iterToken.iterate_balance_valid(keyIndex);
            keyIndex = iterToken.iterate_balance_next(keyIndex)){
            address addr;
            uint256 balance;
            (addr,balance) = iterToken.iterate_balance_get(keyIndex);
            uint256 _payback = balance.mul(tokenPayback).div(_calDecimal);
            _transferPayback(addr,optionsItem.options.collateralCurrency,_payback);
        }
        emit Exercise(msg.sender,tokenAddress);
    }
    /**
      * @dev  transfer collateral payback amount;
      * @param recieptor payback recieptor
      * @param collateral collateral address
      * @param payback amount of collateral will payback 
      */
    function _transferPayback(address recieptor,address collateral,uint256 payback)internal{
        if (collateral == address(0)){
            recieptor.transfer(payback);
        }else{
            IERC20 collateralToken = IERC20(collateral);
            collateralToken.transfer(recieptor,payback);
        }
    }
    /**
      * @dev  calculate an options token exercise payback and each writer's payment;
      * @param optionsItem the options token information
      */
    function _calExerciseTokenPayback(IndexValue storage optionsItem) internal returns (uint256){
        //calculate tokenPayback
        uint256 underlyingPrice = _oracle.getUnderlyingPrice(optionsItem.options.underlyingAssets);
        uint256 tokenPayback = 0;
        
        if (optionsItem.options.optType == OptionsType.OptCall){
            emit DebugEvent(6,underlyingPrice,uint256(optionsItem.options.underlyingAssets));
            if (underlyingPrice > optionsItem.options.strikePrice){
                tokenPayback = underlyingPrice.sub(optionsItem.options.strikePrice);
            }
        }else{
            emit DebugEvent(7,underlyingPrice,uint256(optionsItem.options.underlyingAssets));
            if ( underlyingPrice < optionsItem.options.strikePrice){
                tokenPayback = optionsItem.options.strikePrice.sub(underlyingPrice);
            }
        }
        if (tokenPayback == 0 ){
            return;
        }
        uint256 collateralPrice = _oracle.getPrice(optionsItem.options.collateralCurrency);
        assert(collateralPrice>0);
        //calculate all pay back collateral and transactionFee
        uint256 allPayback = 0;
        uint256 allTransFee = 0;
        uint256 totalSuply = 0;
        for(uint256 i=0;i<optionsItem.writers.length;i++){
            uint256 _payback = tokenPayback.mul(optionsItem.writers[i].OptionsTokenAmount);
            _payback = _payback.div(collateralPrice);
            uint256 _transFee;
            (_payback,_transFee) = _calSufficientPayback(_payback,optionsItem.writers[i].collateralAmount);
            uint256 bothPay = _payback.add(_transFee);
            optionsItem.writers[i].collateralAmount = optionsItem.writers[i].collateralAmount.sub(bothPay);
            allPayback = allPayback.add(_payback);
            allTransFee = allTransFee.add(_transFee);
            totalSuply = totalSuply.add(optionsItem.writers[i].OptionsTokenAmount);
        }
        emit DebugEvent(9,allTransFee,totalSuply);
        //assert iterToken.gettotalsuply != totalsuply
        managerFee[optionsItem.options.collateralCurrency] =
            managerFee[optionsItem.options.collateralCurrency].add(allTransFee);
        tokenPayback = allPayback.mul(_calDecimal).div(totalSuply);    
        return tokenPayback;
    }
    /**
      * @dev  mint options token. test if writer's collateral assets are sufficient;
      * @param optionsToken the options token address
      * @param collateral the collateral address
      * @param amount the amount of adding collateral
      * @param mintOptionsTokenAmount the amount of new mint options token;
      */
    function _mintOptionsToken(address optionsToken,address collateral,uint256 amount,uint256 mintOptionsTokenAmount)private returns(bool){
        uint256 allCollateral = 0;
        uint256 allMintToken = 0;
        OptionsWriter[] storage writers = optionsMap[optionsToken].writers;
        for (uint256 i=0;i<writers.length;i++){
            if (writers[i].writer == msg.sender){
                break;
            }
        }
        if(i != writers.length){
            allCollateral = writers[i].collateralAmount;
            allMintToken = writers[i].OptionsTokenAmount;
        }
        allMintToken = allMintToken.add(mintOptionsTokenAmount);
        if (collateral == address(0)){
//            require(msg.value > 0,"Must transfer some coins");
            allCollateral = allCollateral.add(msg.value);
        }else if (amount > 0){
            IERC20 oToken = IERC20(collateral);
            oToken.transferFrom(msg.sender, address(this), amount);
            allCollateral = allCollateral.add(amount);
        }
        emit DebugEvent(11,allCollateral,allMintToken);
        require(_isSufficientCollateral(optionsMap[optionsToken].options,allCollateral,allMintToken),"Collateral is insufficient");
        if (i == writers.length){
            optionsMap[optionsToken].writers.push(OptionsWriter(msg.sender,allCollateral,allMintToken));
        }else{
            optionsMap[optionsToken].writers[i].collateralAmount = allCollateral;
            optionsMap[optionsToken].writers[i].OptionsTokenAmount = allMintToken;
        }
        //mint
        if (mintOptionsTokenAmount>0){
            IIterableToken itoken = IIterableToken(optionsToken);
            itoken.mint(msg.sender,mintOptionsTokenAmount);
        }
        return true;
    }
    /**
      * @dev  burn options token.;
      * @param optionsToken the options token address
      * @param burnOptionsTokenAmount the amount of new options token will be burnt;
      */
    function _burnOptionsToken(address optionsToken,uint256 burnOptionsTokenAmount)private returns(bool){
        uint256 allCollateral = 0;
        uint256 allMintToken = 0;
        OptionsWriter[] storage writers = optionsMap[optionsToken].writers;
        uint256 index = writers.length;
        for (uint256 i=0;i<writers.length;i++){
            if (writers[i].writer == msg.sender){
                index = i;
                break;
            }
        }
        if(index!= writers.length){
            allCollateral = writers[index].collateralAmount;
            allMintToken = writers[index].OptionsTokenAmount;
        }else{
            return false;
        }
        allMintToken = allMintToken.sub(burnOptionsTokenAmount);

        if (_isSufficientCollateral(optionsMap[optionsToken].options,allCollateral,allMintToken)){
            optionsMap[optionsToken].writers[index].collateralAmount = allCollateral;
            optionsMap[optionsToken].writers[index].OptionsTokenAmount = allMintToken;
        }else{
            return false;
        }
        return true;
    }
    function _calSufficientPayback(uint256 payback,uint256 colleteralAmount)internal view returns(uint256,uint256){
        uint256 _transFee = _calNumberMulUint(transactionFee,payback);
        uint256 bothPay = payback.add(_transFee);
        if (bothPay>colleteralAmount){
            bothPay = colleteralAmount;
            _transFee = _calNumberMulUint(transactionFee,bothPay);
            payback = bothPay.sub(_transFee);
        }
        emit DebugEvent(12,colleteralAmount,bothPay);
        return (payback,_transFee);
    }
    function _isSufficientCollateral(OptionsInfo storage options,uint256 allCollateral,uint256 allMintToken) internal view returns (bool){
        uint256 collateralValue = _calCollateralValue(options.collateralCurrency,allCollateral);
        uint256 underlyingPrice = _oracle.getUnderlyingPrice(options.underlyingAssets);
        emit DebugEvent(13,underlyingPrice,options.strikePrice);
        uint256 needCollateral = 0;
        if (options.optType == OptionsType.OptCall){
            needCollateral = _optionsFormulas.callCollateralPrice(options.strikePrice,underlyingPrice);            
            emit DebugEvent(14,collateralValue,needCollateral);
            needCollateral = needCollateral.mul(allMintToken);
            if (needCollateral > collateralValue){
                return false;
            }
        }else{
            needCollateral = _optionsFormulas.putCollateralPrice(options.strikePrice,underlyingPrice);
            emit DebugEvent(15,collateralValue,needCollateral);
            needCollateral = needCollateral.mul(allMintToken);
            if (needCollateral > collateralValue){
                return false;
            }
        }
        return true;
    }

    function _calCollateralValue(address collateral,uint256 amount)internal view returns(uint256){
        uint256 price = _oracle.getPrice(collateral);
        uint256 value = amount.mul(price);
        return value;
    }
    function _calNumberMulUint(Number number,uint256 value) internal pure returns (uint256){
        uint256 result = number.value.mul(value);
        if (number.exponent > 0) {
            result = result.mul(10**uint256(number.exponent));
        } else {
            result = result.div(10**uint256(-1*number.exponent));
        }
        return result;
    }
    function _isExpired(IndexValue storage optionsItem) internal view returns (bool){
        return optionsItem.options.expiration<now;
    }
    function _isExercised(IndexValue storage optionsItem) internal view returns (bool){
        return optionsItem.options.isExercised;
    }
}
