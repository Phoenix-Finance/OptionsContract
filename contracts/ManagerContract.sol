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
        uint256 i = _findWriter(key,msg.sender);

        if (i == writers.length){
            optionsMap[key].writers.push(OptionsWriter(msg.sender,amount,mintOptTokenAmount));
        }else{
            optionsMap[key].writers[i].collateralAmount = optionsMap[key].writers[i].collateralAmount.add(amount);
            optionsMap[key].writers[i].OptionsTokenAmount = optionsMap[key].writers[i].OptionsTokenAmount.add(mintOptTokenAmount);
        }
        return true;
    }
    function _findWriter(address key,address writer) internal view returns (uint256){
        OptionsWriter[] storage writers = optionsMap[key].writers;
        for (uint256 i=0;i<writers.length;i++ ){
            if (writers[i].writer == writer){
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
    IOptFormulas internal _optionsFormulas;
    ICompoundOracle internal _oracle;
    uint256 private _calDecimal = 10000000000;
    // Number(2,-1) = 20%
    Number public liquidationIncentive = Number(2, -1);
    
    event CreateOptions(address indexed collateral,address indexed tokenAddress, uint32 indexed underlyingAssets,uint256 strikePrice,uint256 expiration,uint8 optType);
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
        uint256 index = _findWriter(optionsToken,msg.sender);
        require(index != writers.length,"Option token writer is not exist");
        OptionsWriter[] storage writers = optionsMap[optionsToken].writers;
        uint256 allCollateral = writers[index].collateralAmount.sub(amount);
        uint256 allMintToken = writers[index].OptionsTokenAmount;
        require (_isSufficientCollateral(optionsMap[optionsToken].options,allCollateral,allMintToken),"option token writter's Collateral is insufficient");

        _transferPayback(msg.sender,optionsMap[optionsToken].options.collateralCurrency,amount);

        optionsMap[optionsToken].writers[index].collateralAmount = allCollateral;
        emit WithdrawCollateral(optionsToken,amount);

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
        uint256 i = _findWriter(optionsToken,writer);
        require(i != optionsItem.writers.length,"Option token writer is not exist");

        require(amount <= optionsItem.writers[i].OptionsTokenAmount,"liquidated token amount exceeds writter's mintToken amount");
        require(!_isSufficientCollateral(optionsItem.options,
            optionsItem.writers[i].collateralAmount,
            optionsItem.writers[i].OptionsTokenAmount),"option token writter's Collateral is sufficient");
        IERC20 optToken = IERC20(optionsToken);
        optToken.transferFrom(msg.sender, address(this), amount);
        uint256 tokenPrice = _oracle.getBuyOptionsPrice(optionsToken);
        uint256 _payback = tokenPrice.mul(amount);
        uint256 price = _oracle.getPrice(optionsItem.options.collateralCurrency);
        _payback = _payback.div(price);
        uint256 incentive = _calNumberMulUint(liquidationIncentive,_payback);
        _payback = _payback.add(incentive);
        uint256 _transFee;
        (_payback, _transFee) = _calSufficientPayback(_payback,optionsItem.writers[i].collateralAmount);
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
        uint256 i= _findWriter(optionsToken,msg.sender);
        require  (i != optionsItem.writers.length, "Option token writer is not exist");
        require( amount <= optionsItem.writers[i].OptionsTokenAmount,"options  writer's token is insufficient!");
        IERC20 optToken = IERC20(optionsToken);
        optToken.transferFrom(msg.sender, address(this), amount);
        optionsItem.writers[i].OptionsTokenAmount = optionsItem.writers[i].OptionsTokenAmount.sub(amount);
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
        emit DebugEvent(1111,optionsItem.options.expiration,now);
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
        emit DebugEvent(2222,tokenPayback,2222);
        if (tokenPayback > 0 ){
            //calculate balance pay back
            IIterableToken iterToken = IIterableToken(tokenAddress);
            (address[] memory accounts,uint256[] memory  balances) = iterToken.getAccountsAndBalances();
            if (optionsItem.options.collateralCurrency == address(0)){
                for (i=0;i<accounts.length;i++){
                    if (balances[i]>0){
                        value = _findWriter(tokenAddress,accounts[i]);
                        if (value == optionsItem.writers.length){ //not writer
                            value = balances[i].mul(tokenPayback).div(_calDecimal);
                            emit DebugEvent(3333,i,value);
                            accounts[i].transfer(value);
                        }
                    }
                }
            }else{
                for (i=0;i<accounts.length;i++){
                    if (balances[i]>0){
                        value = _findWriter(tokenAddress,accounts[i]);
                        if (value == optionsItem.writers.length){ //not writer
                            value = balances[i].mul(tokenPayback).div(_calDecimal);
                            collateralToken.transfer(accounts[i],value);
                        }
                    }
                }
            }
        }
        //return Collateral
        if (optionsItem.options.collateralCurrency == address(0)){
            for (i=0;i<optionsItem.writers.length;i++){
                if (optionsItem.writers[i].collateralAmount > 0){
                    optionsItem.writers[i].writer.transfer(optionsItem.writers[i].collateralAmount);
                }
            }
        }else{
            for (i=0;i<optionsItem.writers.length;i++){
                if (optionsItem.writers[i].collateralAmount > 0){
                   collateralToken.transfer(optionsItem.writers[i].writer,optionsItem.writers[i].collateralAmount);
                }
            }
        }
        _remove(tokenAddress);
        emit Exercise(msg.sender,tokenAddress);        
    }
    /**
      * @dev  transfer collateral payback amount;
      * @param recieptor payback recieptor
      * @param collateral collateral address
      * @param payback amount of collateral will payback 
      */
    function _transferPayback(address recieptor,address collateral,uint256 payback)internal{
        if (payback == 0){
            return;
        }
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
    function _calExerciseTokenPayback(address tokenAddress,IndexValue storage optionsItem) internal returns (uint256){
        //calculate tokenPayback
        uint256 underlyingPrice = _oracle.getUnderlyingPrice(optionsItem.options.underlyingAssets);
        uint256 tokenPayback = 0;
        emit DebugEvent(4444,underlyingPrice,optionsItem.options.strikePrice);
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
        uint256 collateralPrice = _oracle.getPrice(optionsItem.options.collateralCurrency);
        assert(collateralPrice>0);
        //calculate all pay back collateral and transactionFee
        uint256 allPayback = 0;
        uint256 allTransFee = 0;
        uint256 totalSuply = 0;
        IERC20 ercToken = IERC20(tokenAddress);
        for(uint256 i=0;i<optionsItem.writers.length;i++){
            if (optionsItem.writers[i].OptionsTokenAmount == 0){
                continue;
            } 
            uint256 _payback = tokenPayback.mul(optionsItem.writers[i].OptionsTokenAmount);
            _payback = _payback.div(collateralPrice);
            uint256 _transFee;
            (_payback,_transFee) = _calSufficientPayback(_payback,optionsItem.writers[i].collateralAmount);
            uint256 leftToken = ercToken.balanceOf(optionsItem.writers[i].writer);
            leftToken = optionsItem.writers[i].OptionsTokenAmount - leftToken;
            _payback = _payback.mul(leftToken).div(optionsItem.writers[i].OptionsTokenAmount);
            allPayback = allPayback.add(_payback);
            allTransFee = allTransFee.add(_transFee);
            totalSuply = totalSuply.add(leftToken);
            _payback = _payback.add(_transFee);   
            optionsItem.writers[i].collateralAmount = optionsItem.writers[i].collateralAmount.sub(_payback);
        }
        emit DebugEvent(9,allTransFee,totalSuply);
        //assert iterToken.gettotalsuply != totalsuply
        _addTransactionFee(optionsItem.options.collateralCurrency, allTransFee);
        if (totalSuply == 0){
            return 0;
        }
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
        uint256 i = _findWriter(optionsToken,msg.sender);
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
    function _calSufficientPayback(uint256 payback,uint256 colleteralAmount)internal view returns(uint256,uint256){
        uint256 _transFee = _calNumberMulUint(transactionFee,payback);
        uint256 bothPay = payback.add(_transFee);
        if (bothPay>colleteralAmount){
            bothPay = colleteralAmount;
            _transFee = _calNumberMulUint(transactionFee,bothPay);
            payback = bothPay.sub(_transFee);
        }
        return (payback,_transFee);
    }
    function _isSufficientCollateral(OptionsInfo storage options,uint256 allCollateral,uint256 allMintToken) internal view returns (bool){
        uint256 price = _oracle.getPrice(options.collateralCurrency);
        uint256 underlyingPrice = _oracle.getUnderlyingPrice(options.underlyingAssets);
        uint256 maxMint = _optionsFormulas.calculateMaxMintAmount(price,allCollateral,options.strikePrice,underlyingPrice,uint8(options.optType));
        return maxMint>=allMintToken;
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
