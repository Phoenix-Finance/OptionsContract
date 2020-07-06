pragma solidity ^0.4.26;
import "./SafeMath.sol";
import "./IERC20.sol";
import "./Ownable.sol";
import "./ReentrancyGuard.sol";
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
    struct IndexValue
    {
        uint keyIndex;
        OptionsInfo options;
        address[] writers;
    }
    struct KeyFlag { address key; bool deleted; }
    mapping(address => IndexValue) internal optionsMap;
    //collateral => writer => amount
    mapping(address => mapping(address => uint256)) writerVaults;
    //options => writer =>  amount
    mapping(address => mapping(address => uint256)) writerOptions;
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
        uint256 i = _findWriter(key,msg.sender);
        if (i == optionsMap[key].writers.length){
            optionsMap[key].writers.push(msg.sender);
        }
        OptionsInfo storage options = optionsMap[key].options;
        writerVaults[options.collateralCurrency][msg.sender] = amount.add(writerVaults[options.collateralCurrency][msg.sender]);
        writerOptions[key][msg.sender] = mintOptTokenAmount.add(writerOptions[key][msg.sender]);
        return true;
    }
    function _findWriter(address key,address writer) internal view returns (uint256){
        address[] storage writers = optionsMap[key].writers;
        for (uint256 i=0;i<writers.length;i++ ){
            if (writers[i] == writer){
                break;
            }
        }
        return i;
    }
    function _remove(address key) internal returns (bool)
    {
        uint keyIndex = optionsMap[key].keyIndex;
        if (keyIndex == 0)
            return false;
        address[] storage writers = optionsMap[key].writers;
        for (uint256 i=0;i<writers.length;i++ ){
            delete writerOptions[key][writers[i]];
        }
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
    function getOptionsTokenWriterList(address tokenAddress)public view returns (address[]){
            return optionsMap[tokenAddress].writers;
    }
    function getWriterCollateralBalance(address writer,address collateral)public view returns (uint256){
            return writerVaults[collateral][writer];
    }
    function getWriterOptionsTokenBalance(address writer,address tokenAddress)public view returns (uint256){
            return writerOptions[tokenAddress][writer];
    }
    function getOptionsTokenInfo(address tokenAddress)public view returns (uint8,address,uint32,uint256,uint256,bool){
        if (_contains(tokenAddress)){
            OptionsInfo storage options = optionsMap[tokenAddress].options;
            return (uint8(options.optType),options.collateralCurrency,options.underlyingAssets,
                options.strikePrice,options.expiration,options.isExercised);
        }
    }
}
contract OptionsManager is OptionsVault,ReentrancyGuard {
    using SafeMath for uint256;
    IOptFormulas internal _optionsFormulas;
    ICompoundOracle internal _oracle;
    uint256 private _calDecimal = 10000000000;
    // Number(2,-1) = 20%
    Number public liquidationIncentive = Number(2, -1);
    
    event CreateOptions(address indexed collateral,address indexed tokenAddress, uint32 indexed underlyingAssets,uint256 strikePrice,uint256 expiration,uint8 optType);
    event AddCollateral(address indexed optionsToken,uint256 indexed amount,uint256 mintOptionsTokenAmount);
    event WithdrawCollateral(address indexed Sender,address indexed collateral,uint256 amount);
    event Exercise(address indexed Sender,address indexed optionsToken,uint256 unitPrice);
    event ExercisePayback(address indexed optionsToken,address indexed recieptor,address indexed collateral,uint256 payback);
    event Liquidate(address indexed Sender,address indexed optionsToken,address indexed writer,uint256 amount,uint256 payback);
    event BurnOptionsToken(address indexed optionsToken,address indexed writer,uint256 amount);
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
    public onlyOwner nonReentrant{
        require(underlyingAssets>0 , "underlying cannot be zero");
        require(isEligibleAddress(collateral) , "collateral is unsupported token");
//        expiration = expiration.add(now);
        //new OptionsToken(expiration,optionsTokenName);
        address newToken = _optionsFormulas.createNewToken(expiration,optionsTokenName);
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
    function addCollateral(address optionsToken,address collateral,uint256 amount,uint256 mintOptionsTokenAmount)public payable nonReentrant{
        require(_contains(optionsToken),"This OptionsToken does not exist");
        require(!_isExpired(optionsMap[optionsToken]), "This OptionsToken expired");
        require(optionsMap[optionsToken].options.collateralCurrency == collateral,"Collateral currency type error");
        _mintOptionsToken(optionsToken,collateral,amount,mintOptionsTokenAmount);
        emit AddCollateral(optionsToken,amount,mintOptionsTokenAmount);
    }
     /**
        * @dev  Withdraw Collateral. Any writer can withdraw his collateral if his collateral assets are surplus;
        * @param collateral The collateral address.
        * @param amount The amount  collateral asset which will be Withdrawn
        */   
    function withdrawCollateral(address collateral,uint256 amount)public nonReentrant{
        require(isEligibleAddress(collateral) , "collateral is unsupported token");
        writerVaults[collateral][msg.sender] = writerVaults[collateral][msg.sender].sub(amount);
        require (_isSufficientCollateral(collateral,msg.sender,address(0),0,0),"option token writter's Collateral is insufficient");
        _transferPayback(msg.sender,collateral,amount);
        emit WithdrawCollateral(msg.sender,collateral,amount);

    }
    /**
      * @dev  exercise all of the expired options token;
      */  
    function exercise()public nonReentrant{
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
    function liquidate(address optionsToken,address writer,uint256 amount)public nonReentrant{
        require(_contains(optionsToken),"This OptionsToken does not exist");
        IndexValue storage optionsItem = optionsMap[optionsToken];
        require(!_isExpired(optionsItem), "OptionsToken expired");
        require(amount <= writerOptions[optionsToken][writer],"liquidated token amount exceeds writter's mintToken amount");
        require(!_isSufficientCollateral(optionsItem.options.collateralCurrency,writer,
            optionsToken,0,0),"option token writter's Collateral is sufficient");
        IERC20 optToken = IERC20(optionsToken);
        optToken.transferFrom(msg.sender, address(this), amount);
        uint256 tokenPrice = _oracle.getBuyOptionsPrice(optionsToken);
        uint256 _payback = tokenPrice.mul(amount);
        uint256 price = _oracle.getPrice(optionsItem.options.collateralCurrency);
        _payback = _payback.div(price);
        uint256 incentive = _calNumberMulUint(liquidationIncentive,_payback);
        _payback = _payback.add(incentive);
        if (_payback > writerVaults[optionsItem.options.collateralCurrency][writer]) {
            _payback = writerVaults[optionsItem.options.collateralCurrency][writer];
        }
        uint256 _transFee = _calNumberMulUint(transactionFee,_payback);
        
        writerVaults[optionsItem.options.collateralCurrency][writer] = writerVaults[optionsItem.options.collateralCurrency][writer].sub(_payback);
        _addTransactionFee(optionsItem.options.collateralCurrency,_transFee);
        writerOptions[optionsToken][writer] = writerOptions[optionsToken][writer].sub(amount);
        //transfer
        _transferPayback(msg.sender,optionsItem.options.collateralCurrency,_payback.sub(_transFee));
        IIterableToken itoken = IIterableToken(optionsToken);
        itoken.burn(amount);
        emit Liquidate(msg.sender,optionsToken,writer,amount,_payback.sub(_transFee));
    }
    /**
      * @dev  A options writer burn some of his own token;
      * @param optionsToken The Options token address.
      * @param amount The amount of options token which will be burned
      */     
    function burnOptionsToken(address optionsToken,uint256 amount)public nonReentrant{
       require(_contains(optionsToken),"This OptionsToken does not exist");
        IndexValue storage optionsItem = optionsMap[optionsToken];
        require(!_isExpired(optionsItem), "OptionsToken expired");
        require(amount <= writerOptions[optionsToken][msg.sender],"options writer's token is insufficient!");
        IERC20 optToken = IERC20(optionsToken);
        optToken.transferFrom(msg.sender, address(this), amount);
        writerOptions[optionsToken][msg.sender] = writerOptions[optionsToken][msg.sender].sub(amount);
        //burn
        IIterableToken itoken = IIterableToken(optionsToken);
        itoken.burn(amount);
        emit BurnOptionsToken(optionsToken,msg.sender,amount);
    }
    /**
      * @dev  exercise an options token;
      * @param tokenAddress The Options token address.
      * @param optionsItem The Options token information and writer information list.

      */  
    function _exercise(address tokenAddress,IndexValue storage optionsItem)internal {
        if (!_isExpired(optionsItem) || _isExercised(optionsItem)){
            return;
        }
        if (optionsItem.writers.length == 0) {
            optionsItem.options.isExercised = true;
            _remove(tokenAddress);
            return;
        }
        optionsItem.options.isExercised = true;
        uint256 i=0;
        uint256 value;
        IERC20 collateralToken = IERC20(optionsItem.options.collateralCurrency);
        //calculate tokenPayback
        uint256 tokenPayback = _calExerciseTokenPayback(tokenAddress,optionsItem);
        if (tokenPayback > 0 ){
            //calculate balance pay back
            IIterableToken iterToken = IIterableToken(tokenAddress);
            (address[] memory accounts,uint256[] memory  balances) = iterToken.getAccountsAndBalances();
            if (optionsItem.options.collateralCurrency == address(0)){
                for (i=0;i<accounts.length;i++){
                    if (balances[i]>0){
                        if (writerOptions[tokenAddress][accounts[i]] == 0){ //not writer
                            value = balances[i].mul(tokenPayback).div(_calDecimal);
                            accounts[i].transfer(value);
                            emit ExercisePayback(tokenAddress,accounts[i],optionsItem.options.collateralCurrency,value);
                        }
                    }
                }
            }else{
                for (i=0;i<accounts.length;i++){
                    if (balances[i]>0){
                        if (writerOptions[tokenAddress][accounts[i]] == 0){ //not writer
                            value = balances[i].mul(tokenPayback).div(_calDecimal);
                            collateralToken.transfer(accounts[i],value);
                            emit ExercisePayback(tokenAddress,accounts[i],optionsItem.options.collateralCurrency,value);
                        }
                    }
                }
            }
        }
        _remove(tokenAddress);
        emit Exercise(msg.sender,tokenAddress,tokenPayback);
    }
    /**
      * @dev  calculate an options token exercise payback and each writer's payment;
      * @param optionsItem the options token information
      */
    function _calExerciseTokenPayback(address tokenAddress,IndexValue storage optionsItem) internal returns (uint256){
        //calculate tokenPayback
        uint256 underlyingPrice = _oracle.getUnderlyingPrice(optionsItem.options.underlyingAssets);
        uint256 tokenPayback = 0;
        if (optionsItem.options.optType == OptionsType.OptCall){
            if (underlyingPrice > optionsItem.options.strikePrice){
                tokenPayback = underlyingPrice.sub(optionsItem.options.strikePrice);
            }
        }else{
            if ( underlyingPrice < optionsItem.options.strikePrice){
                tokenPayback = optionsItem.options.strikePrice.sub(underlyingPrice);
            }
        }
        if (tokenPayback == 0 ){
            return 0;
        }

        //calculate all pay back collateral and transactionFee
        uint256 allPayback = 0;
        uint256 totalSuply = 0;

        for(uint256 i=0;i<optionsItem.writers.length;i++){
            (uint256 _payback,uint leftToken) = _CalWriterPayback(tokenAddress,optionsItem.writers[i],optionsItem.options.collateralCurrency,tokenPayback);
            allPayback = allPayback.add(_payback);
            totalSuply = totalSuply.add(leftToken);
        }
        //assert iterToken.gettotalsuply != totalsuply
        if (totalSuply == 0){
            return 0;
        }
        return allPayback.mul(_calDecimal).div(totalSuply);    
    }
    function _CalWriterPayback(address tokenAddress, address writer,address collateral,uint256 tokenPayback)private returns (uint256,uint256){
        uint256 collateralPrice = _oracle.getPrice(collateral);
        assert(collateralPrice>0);
        if(writerOptions[tokenAddress][writer] == 0){
            return (0,0);
        }
        IERC20 ercToken = IERC20(tokenAddress);
        uint256 _payback = tokenPayback.mul(writerOptions[tokenAddress][writer]);
        _payback = _payback.div(collateralPrice);
        if (_payback >writerVaults[collateral][writer]) {
            _payback = writerVaults[collateral][writer];
        }
        uint leftToken = writerOptions[tokenAddress][writer] - ercToken.balanceOf(writer);
        _payback = _payback.mul(leftToken).div(writerOptions[tokenAddress][writer]);
        uint256 _transFee =_calNumberMulUint(transactionFee,_payback);
        
        _addTransactionFee(collateral, _transFee);
        
        writerVaults[collateral][writer] =
                writerVaults[collateral][writer].sub(_payback);  
        return (_payback.sub(_transFee),leftToken);
    }
    /**
      * @dev  mint options token. test if writer's collateral assets are sufficient;
      * @param optionsToken the options token address
      * @param collateral the collateral address
      * @param amount the amount of adding collateral
      * @param mintOptionsTokenAmount the amount of new mint options token;
      */
    function _mintOptionsToken(address optionsToken,address collateral,uint256 amount,uint256 mintOptionsTokenAmount)private returns(bool){
        uint256 colAmount = 0;
        if (collateral == address(0)){
//            require(msg.value > 0,"Must transfer some coins");
            colAmount = msg.value;
        }else if (amount > 0){
            IERC20 oToken = IERC20(collateral);
            oToken.transferFrom(msg.sender, address(this), amount);
            colAmount = amount;
        }
        require(_isSufficientCollateral(collateral,msg.sender,optionsToken,colAmount,mintOptionsTokenAmount),"Collateral is insufficient");
        _insertWriter(optionsToken,colAmount,mintOptionsTokenAmount);
        //mint
        if (mintOptionsTokenAmount>0){
            IIterableToken itoken = IIterableToken(optionsToken);
            itoken.mint(msg.sender,mintOptionsTokenAmount);
        }
        return true;
    }
    function _isSufficientCollateral(address collateral,address writer,address optionToken,uint256 newCollateral,uint256 newMintToken) internal view returns (bool){
        uint256 totalUsd = calculateOptionsValueUSD(collateral,writer);
        if(newMintToken>0 && _contains(optionToken)){
            uint256 underlyingPrice = _oracle.getUnderlyingPrice(optionsMap[optionToken].options.underlyingAssets);
            uint256 needCollateral = _optionsFormulas.getCollateralPrice(optionsMap[optionToken].options.strikePrice,
                        underlyingPrice,uint8(optionsMap[optionToken].options.optType));
            totalUsd = totalUsd.add(newMintToken.mul(needCollateral));
        }
        uint256 price = _oracle.getPrice(collateral);
        uint256 totalColateral = price.mul(writerVaults[collateral][writer].add(newCollateral));
        return totalColateral>=totalUsd;
    } 
    function calculateMaxMintAmount(address collateral,address writer,address optionToken,uint256 newCollateral)public view returns(uint256){
        uint256 price = _oracle.getPrice(collateral);
        uint256 totalColateral = price.mul(writerVaults[collateral][writer].add(newCollateral));
        totalColateral = totalColateral.sub(calculateOptionsValueUSD(collateral,writer));
        uint256 underlyingPrice = _oracle.getUnderlyingPrice(optionsMap[optionToken].options.underlyingAssets);
        uint256 needCollateral = _optionsFormulas.getCollateralPrice(optionsMap[optionToken].options.strikePrice,
                    underlyingPrice,uint8(optionsMap[optionToken].options.optType));
        return totalColateral.div(needCollateral);
    }
    function calculateOptionsValueUSD(address collateral,address writer)public view returns(uint256){
        uint256 totalUsd = 0;
        address[] memory tokenList = getOptionsTokenList();
        for(uint256 i=0;i<tokenList.length;i++){
            OptionsInfo storage options = optionsMap[tokenList[i]].options;
            if (options.collateralCurrency != collateral){
                continue;
            }
            uint256 tokenAmount = writerOptions[tokenList[i]][writer];
            uint256 underlyingPrice = _oracle.getUnderlyingPrice(options.underlyingAssets);
            uint256 needCollateral = _optionsFormulas.getCollateralPrice(options.strikePrice,underlyingPrice,uint8(options.optType));
            totalUsd = totalUsd.add(tokenAmount.mul(needCollateral));
        }
        return totalUsd;
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