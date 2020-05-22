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
                uint256 strikePriceValue,
                int32 strikePirceExponent) internal returns (bool replaced)
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
        uint256 index = writers.length;
        for (uint256 i=0;i<writers.length;i++ ){
            if (writers[i].writer == msg.sender){
                index = i;
                break;
            }
        }
        if (index == writers.length){
            optionsMap[key].writers.push(OptionsWriter(msg.sender,amount,mintOptTokenAmount));
        }else{
            optionsMap[key].writers[index].collateralAmount = optionsMap[key].writers[i].collateralAmount.add(amount);
            optionsMap[key].writers[index].OptionsTokenAmount = optionsMap[key].writers[i].OptionsTokenAmount.add(mintOptTokenAmount);
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
}
contract OptionsManager is OptionsVault {
    using SafeMath for uint256;
        constructor() public {
        
    }
    IOptFormulas internal _optionsFormulas;
    ICompoundOracle internal _oracle;

    // Number(10,-3) = 0.3%
    Number public liquidationIncentive = Number(10, -3);
    
    event CreateOptions (address indexed collateral,address indexed tokenAddress, uint32 indexed underlyingAssets,uint256 strikePrice,uint256 expiration,uint8 optType);
    event AddCollateral(address indexed optionsToken,uint256 indexed amount,uint256 mintOptionsTokenAmount);
    event WithdrawCollateral(address indexed optionsToken,uint256 amount);
    event Exercise(address indexed Sender,address indexed optionsToken);
    event Liquidate(address indexed Sender,address indexed optionsToken,address indexed writer,uint256 amount);
    event BurnOptionsToken(address indexed optionsToken,address indexed writer,uint256 amount);




    //*******************getter***********************
    function getOracleAddress() public view returns(address){
        return address(_oracle);
    }
    function getFormulasAddress() public view returns(address){
        return address(_optionsFormulas);
    }
    function getCollateralList()public view returns (address[]){
        return getWhiteList();
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
    function addCollateralCurrency(address tokenAddress)public onlyOwner{
        addWhiteList(tokenAddress);
    }
    function removeCollateralCurrency(address tokenAddress)public onlyOwner{
        removeWhiteList(tokenAddress);
    }
    function setLiquidationIncentive(uint256 value,int32 exponent)public onlyOwner{
        liquidationIncentive.value = value;
        liquidationIncentive.exponent = exponent;
    }
    /**
        * @param collateral The collateral asset
        * @param collExp The precision of the collateral (-18 if ETH)
        */
    function createOptionsToken(address collateral,
    int32 collExp,
    uint32 underlyingAssets,
    uint256 strikePrice,
    int32 strikeExp,
    uint256 expiration,
    uint8 optType)
    public onlyOwner{
        require(isCollateralCurrency(collateral) , "It is unsupported token");
        address newToken = new OptionsToken(expiration,"otoken");
        assert(newToken != 0);
        _insert(newToken,OptionsType(optType),collateral,underlyingAssets,expiration,strikePrice,strikeExp);
        emit CreateOptions(collateral,newToken,underlyingAssets,strikePrice,expiration,optType);
        
    }
    function addCollateral(address optionsToken,address collateral,uint256 amount,uint256 mintOptionsTokenAmount)public payable{
        require(_contains(optionsToken),"This OptionsToken does not exist");
        require(!_isExpired(optionsMap[optionsToken]), "This OptionsToken expired");
        require(optionsMap[optionsToken].options.collateralCurrency == collateral,"Collateral currency type error");

        _mintOptionsToken(optionsToken,collateral,amount,mintOptionsTokenAmount);
        emit AddCollateral(optionsToken,amount,mintOptionsTokenAmount);
    }
    function withdrawCollateral(address OptionsToken,uint256 amount)public{
        require(_contains(OptionsToken),"This OptionsToken does not exist");
        require(!_isExpired(optionsMap[OptionsToken]), "This OptionsToken expired");
        OptionsWriter[] storage writers = optionsMap[OptionsToken].writers;
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
            if (_isSufficientCollateral(optionsMap[OptionsToken].options,allCollateral,allMintToken)){
                if (optionsMap[OptionsToken].options.collateralCurrency == address (0)){
                    msg.sender.transfer(amount);
                }else{
                    IERC20 oToken = IERC20(optionsMap[OptionsToken].options.collateralCurrency);
                    oToken.transfer(msg.sender,amount);
                }
                optionsMap[OptionsToken].writers[index].collateralAmount = allCollateral;
                emit WithdrawCollateral(OptionsToken,amount);
            }else{

            }
        }else{

        }
    }
    function exercise()public{
        for (uint keyIndex = _iterate_start();_iterate_valid(keyIndex);keyIndex = _iterate_next(keyIndex)){
            IndexValue storage optionsItem = optionsMap[optionsTokenList[keyIndex].key];
            _exercise(optionsTokenList[keyIndex].key,optionsItem);
        }
    }
    function liquidate(address optionsToken,address writer,uint256 amount)public{
        require(_contains(optionsToken),"This OptionsToken does not exist");
        IndexValue storage optionsItem = optionsMap[optionsToken];
        require(!_isExpired(optionsItem), "OptionsToken expired");
        uint256 index = optionsItem.writers.length;
        for(uint256 i=0;i<optionsItem.writers.length;i++){
            if(optionsItem.writers[i].writer == writer){
                index = i;
                break;
            }
        }
        if (index != optionsItem.writers.length) {
            if( amount > optionsItem.writers[index].OptionsTokenAmount){
                return;
            }
            if (_isSufficientCollateral(optionsItem.options,
                optionsItem.writers[index].collateralAmount,
                optionsItem.writers[index].OptionsTokenAmount)){
                return;
            }
            IERC20 optToken = IERC20(optionsToken);
            optToken.transferFrom(msg.sender, address(this), amount);
            uint256 tokenPrice = _oracle.getOptionsPrice(optionsToken);
            uint256 _payback = tokenPrice.mul(amount);
            uint256 price = _oracle.getPrice(optionsItem.options.collateralCurrency);
            _payback = _payback.div(price);
            uint256 incentive = _calNumberMulUint(liquidationIncentive,_payback);
            _payback = _payback.add(incentive);
            uint256 _transFee;
            (_payback,_transFee) = _calSufficientPayback(_payback,optionsItem.writers[i].collateralAmount);
            optionsItem.writers[index].collateralAmount = optionsItem.writers[index].collateralAmount.sub(_payback);
            optionsItem.writers[index].collateralAmount = optionsItem.writers[index].collateralAmount.sub(_transFee);
            managerFee[optionsItem.options.collateralCurrency] = managerFee[optionsItem.options.collateralCurrency].add(_transFee);
            optionsItem.writers[index].OptionsTokenAmount = optionsItem.writers[index].OptionsTokenAmount.sub(amount);
            //transfer
            optToken.transfer(msg.sender,_payback);
            IIterableToken itoken = IIterableToken(optionsToken);
            itoken.burn(amount);
            emit Liquidate(msg.sender,optionsToken,writer,amount);
        }
    }
    function burnOptionsToken(address optionsToken,uint256 amount)public{
       require(_contains(optionsToken),"This OptionsToken does not exist");
        IndexValue storage optionsItem = optionsMap[optionsToken];
        require(!_isExpired(optionsItem), "OptionsToken expired");
        uint256 index = optionsItem.writers.length;
        for(uint256 i=0;i<optionsItem.writers.length;i++){
            if(optionsItem.writers[i].writer == msg.sender){
                index = i;
                break;
            }
        }
        if (index != optionsItem.writers.length) {
            if( amount > optionsItem.writers[index].OptionsTokenAmount){
                return;
            }
            IERC20 optToken = IERC20(optionsToken);
            optToken.transferFrom(msg.sender, address(this), amount);
            optionsItem.writers[index].OptionsTokenAmount = optionsItem.writers[index].OptionsTokenAmount.sub(amount);
            //burn
            IIterableToken itoken = IIterableToken(optionsToken);
            itoken.burn(amount);
            emit BurnOptionsToken(optionsToken,msg.sender,amount);
        }
    }
    function redeem(address collateral)public onlyOwner{
        uint256 fee = managerFee[collateral];
        require (fee > 0, "It's empty balance");
        managerFee[collateral] = 0;
        IERC20 collateralToken = IERC20(collateral);
        if (isETH(collateralToken)){
            msg.sender.transfer(fee);
        }else{
            collateralToken.transfer(msg.sender,fee);
        }
    }

    function isETH(IERC20 _ierc20) public pure returns (bool) {
        return _ierc20 == IERC20(0);
    }
    function isCollateralCurrency(address _collateral) public view returns (bool){
        return isEligibleAddress(_collateral);
    }
    function _exercise(address tokenAddress,IndexValue storage optionsItem)internal {
        if (!_isExpired(optionsItem)  || _isExercised(optionsItem)) {
            return;
        }

        optionsItem.options.isExercised = true;
        //calculate tokenPayback
        uint256 tokenPayback = _calExerciseTokenPayback(optionsItem);
         if (tokenPayback == 0 ){
            return;
        }
       //calculate balance pay back
        IIterableToken iterToken = IIterableToken(tokenAddress);
        IERC20 collateralToken = IERC20(optionsItem.options.collateralCurrency);
        for (uint keyIndex = iterToken.iterate_balance_start();
            iterToken.iterate_balance_valid(keyIndex);
            keyIndex = iterToken.iterate_balance_next(keyIndex)){
            address addr;
            uint256 balance;
            (addr,balance) = iterToken.iterate_balance_get(keyIndex);
            uint256 _payback = balance.mul(tokenPayback);
            if (isETH(collateralToken)){
                addr.transfer(_payback);
            }else{
                collateralToken.transfer(addr,_payback);
            }
        }
        emit Exercise(msg.sender,tokenAddress);
    }
    function _calExerciseTokenPayback(IndexValue storage optionsItem) internal returns (uint256){
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
        //assert iterToken.gettotalsuply != totalsuply
        managerFee[optionsItem.options.collateralCurrency] =
            managerFee[optionsItem.options.collateralCurrency].add(allTransFee);
        tokenPayback = allPayback.div(totalSuply);    
        return tokenPayback;
    }
    function _mintOptionsToken(address optionsToken,address collateral,uint256 amount,uint256 mintOptionsTokenAmount)private returns(bool){
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
        if(index != writers.length){
            allCollateral = writers[index].collateralAmount;
            allMintToken = writers[index].OptionsTokenAmount;
        }
        allMintToken = allMintToken.add(mintOptionsTokenAmount);

        if (collateral == address(0)){
            require(msg.value > 0,"Must transfer some coins");
            allCollateral = allCollateral.add(msg.value);
        }else{
            IERC20 oToken = IERC20(collateral);
            oToken.transferFrom(msg.sender, address(this), amount);
            allCollateral = allCollateral.add(amount);
        }
        if (_isSufficientCollateral(optionsMap[optionsToken].options,allCollateral,allMintToken)){
            if (index == writers.length){
                optionsMap[optionsToken].writers.push(OptionsWriter(msg.sender,allCollateral,allMintToken));
            }else{
                optionsMap[optionsToken].writers[index].collateralAmount = allCollateral;
                optionsMap[optionsToken].writers[index].OptionsTokenAmount = allMintToken;
            }
            //mint
            IIterableToken itoken = IIterableToken(optionsToken);
            itoken.mint(msg.sender,amount);

        }else{
            return false;
        }
        return true;
    }
    function _burnOptionsToken(address OptionsToken,uint256 burnOptionsTokenAmount)private returns(bool){
        uint256 allCollateral = 0;
        uint256 allMintToken = 0;
        OptionsWriter[] storage writers = optionsMap[OptionsToken].writers;
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

        if (_isSufficientCollateral(optionsMap[OptionsToken].options,allCollateral,allMintToken)){
            optionsMap[OptionsToken].writers[index].collateralAmount = allCollateral;
            optionsMap[OptionsToken].writers[index].OptionsTokenAmount = allMintToken;
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
        return (payback,_transFee);
    }
    function _isSufficientCollateral(OptionsInfo storage options,uint256 allCollateral,uint256 allMintToken) internal view returns (bool){
        uint256 collateralValue = _calCollateralValue(options.collateralCurrency,allCollateral);
        uint256 underlyingPrice = _oracle.getUnderlyingPrice(options.underlyingAssets);
        uint256 needCollateral = 0;
        if (options.optType == OptionsType.OptCall){
            needCollateral = _optionsFormulas.callCollateralPrice(options.strikePrice,underlyingPrice);
            needCollateral = needCollateral.mul(allMintToken);
            if (needCollateral > collateralValue){
                return false;
            }
        }else{
            needCollateral = _optionsFormulas.putCollateralPrice(options.strikePrice,underlyingPrice);
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
