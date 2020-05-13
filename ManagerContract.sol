pragma solidity 0.5.10;
import "./SafeMath.sol";
import "./IERC20.sol";
import "./Ownable.sol";
import "./OptionsToken.sol";
import "./IIterableToken.sol";
contract OptionsVault
{
    using SafeMath for uint256;
    /* represents floting point numbers, where number = value * 10 ** exponent
    i.e 0.1 = 10 * 10 ** -3 */
    struct Number {
        uint256 value;
        int32 exponent;
    }
    enum OptionsType{
        OptCall,
        OptPut
    }
    struct OptionsInfo{
        OptionsType	type;
        //Collateral currency address. If this address equals 0, it means that it is Eth;
        address		collateralCurrency;
        //underlying assets type;
        uint32		underlyingAssets;
        uint256		expiration;
        Number      strikePrice;
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
    mapping(address => IndexValue) public optionsMap;
    KeyFlag[] optionsToken;
    uint size;
    function _insert(address key, 
                OptionsType optType,
                address collateral,
                uint32 underlyingAssets,
                uint256 expiration,
                uint256 strikePriceValue,
                int32 strikePirceExponent) private returns (bool replaced)
    {
        uint keyIndex = optionsMap[key].keyIndex;
        optionsMap[key].options.type = optType;
        optionsMap[key].options.collateralCurrency = collateral;
        optionsMap[key].options.underlyingAssets = underlyingAssets;
        optionsMap[key].options.expiration = expiration;
        optionsMap[key].options.strikePrice.value = strikePriceValue;
        optionsMap[key].options.strikePrice.exponent = strikePirceExponent;
        optionsMap[key].options.isExercised = false;
        if (keyIndex > 0)
            return true;
        else
        {
            keyIndex = optionsToken.length++;
            optionsMap[key].keyIndex = keyIndex + 1;
            optionsToken[keyIndex].key = key;
            self.size++;
            return false;
        }
    }
    function _insertWriter( address key, uint256 amount,uint256 mintOptTokenAmount) private returns (bool){
        OptionsWriter[] storage writers = optionsMap[key].writers;
        int index = -1;
        for (int i=0;i<writers.length;i++){
            if (writers[i].writer == msg.sender){
                index = i;
                break;
            }
        }
        if (index == -1){
            optionsMap[key].writers.push(OptionsWriter(msg.sender,amount,mintOptTokenAmount));
        }else{
            optionsMap[key].writers[index].collateralAmount = optionsMap[key].writers[i].collateralAmount.add(amount);
            optionsMap[key].writers[index].OptionsTokenAmount = optionsMap[key].writers[i].OptionsTokenAmount.add(mintOptTokenAmount);
        }
        return true;
    }
    function _remove(address key) private returns (bool)
    {
        uint keyIndex = optionsMap[key].keyIndex;
        if (keyIndex == 0)
            return false;
        delete optionsMap[key];
        optionsToken[keyIndex - 1].deleted = true;
        self.size --;
        return true;
    }
    function _contains(address key) private returns (bool)
    {
        return optionsMap[key].keyIndex > 0;
    }
    function _iterate_start() private returns (uint)
    {
        return iterate_next(self, uint(-1));
    }
    function _iterate_valid(uint keyIndex) private returns (bool)
    {
        return keyIndex < optionsToken.length;
    }
    function _iterate_next( uint keyIndex) private returns (uint)
    {
        keyIndex++;
        while (keyIndex < optionsToken.length && optionsToken[keyIndex].deleted)
            keyIndex++;
        return keyIndex;
    }
    function iterate_get( uint keyIndex) private returns (address key, OptionsWriter value)
    {
        key = optionsToken[keyIndex].key;
        value = optionsMap[key].value;
    }
}
contract OptionsModify is OptionsVault,Ownable {
    using SafeMath for uint256;

    IOptFormulas private _optionsFormulas;
    ICompoundOracle private _oracle;

    struct Currency {
        address tokenAddress;
        byte8   name;
    }
    Currency[] public collateralList;

    // Number(10,-3) = 0.3%
    Number public liquidationIncentive = Number(10, -3);

    // Number(10,-3) = 0.3%
    Number public transactionFee = Number(0, -3);

    //Selling and buying token.
    Number public tokenExchangeRate;

    //*******************getter***********************
    function getOracleAddress() public view returns(address){
        return address(oracle);
    }
    function getFormulasAddress() public view returns(address){
        return address(IOptFormulas);
    }
    function getCollateralList()public view returns (Currency[]){
        return collateralList;
    }
    function getLiquidationIncentive()public view returns (uint256,int32){
        return (liquidationIncentive.value,liquidationIncentive.exponent);
    }
    function getTransactionFee()public view returns (uint256,int32){
        return (transactionFee.value,transactionFee.exponent);
    }
    function getTokenExchangeRate()public view returns (uint256,int32){
        return (tokenExchangeRate.value,tokenExchangeRate.exponent);
    }
    //*******************setter***********************
    function setOracleAddress(address oracle)public onlyowner{
        _oracle = ICompoundOracle(oracle);
    }
    function setFormulasAddress(address formulas)public onlyowner{
        _optionsFormulas = IOptFormulas(formulas);
    }
    function addCollateralCurrency(address tokenAddress,byte8 name)public onlyowner{
        for (int i=0;i<collateralList.length;i++){
            if (collateralList[i].tokenAddress == tokenAddress){
                collateralList[i].name = name;
                return;
            }
        }
        collateralList.push(Currency(tokenAddress,name));
    }
    function removeCollateralCurrency(address tokenAddress)public onlyowner{
        for (int i=0;i<collateralList.length;i++){
            if (collateralList[i].tokenAddress == tokenAddress){
                if (i!=collateralList.length-1){
                    collateralList[i] = collateralList[collateralList.length-1];
                }
                collateralList.length--;
                return;
            }
        }
    }
    function setLiquidationIncentive(uint256 value,int32 exponent)public onlyowner{
        liquidationIncentive.value = value;
        liquidationIncentive.exponent = exponent;
    }
    function setTransactionFee(uint256 value,int32 exponent)public onlyowner{
        transactionFee.value = value;
        transactionFee.exponent = exponent;
    }
    function setTokenExchangeRate(uint256 value,int32 exponent)public onlyowner{
        tokenExchangeRate.value = value;
        tokenExchangeRate.exponent = exponent;
    }

}
contract OptionsManager is OptionsModify {

    mapping (address => uint256) 	private managerFee;

    constructor() public {
        
    }
    /**
        * @param _collateral The collateral asset
        * @param _collExp The precision of the collateral (-18 if ETH)
        */
    function createOptionsToken(address collateral,
    int32 collExp,
    uint32 underlyingAssets,
    uint256 strikePrice,
    int32 strikeExp,
    uint256 expiration,
    optionsType optionsType)
    public onlyOwner{
        require(isCollateralCurrency(collateral) , "It is unsupported token");
        address newToken = new OptionsToken(expiration,"otoken");
        assert(newToken != 0);
        _insert(newToken,optionsType,collateral,underlyingAssets,expiration,strikePrice,strikeExp);
    }
    function addCollateral(address OptionsToken,address collateral,uint256 amount,uint256 mintOptionsTokenAmount)public payable{
        require(_contains(OptionsToken),"This OptionsToken does not exist");
        require(!isExpired(optionsMap[OptionsToken]), "This OptionsToken expired");
        require(optionsMap[OptionsToken].options.collateralCurrency == collateral,"Collateral currency type error");

        _mintOptionsToken(optionsToken,collateral,amount,mintOptionsTokenAmount);
    }
    function withdrawCollateral(address OptionsToken,uint256 amount)public{
        require(_contains(OptionsToken),"This OptionsToken does not exist");
        require(!isExpired(optionsMap[OptionsToken]), "This OptionsToken expired");
        require(optionsMap[OptionsToken].options.collateralCurrency == collateral,"Collateral currency type error");
        OptionsWriter[] storage writers = optionsMap[OptionsToken].writers;
        int index = -1;
        for (int i=0;i<writers.length;i++){
            if (writers[i].writer == msg.sender){
                index = i;
                break;
            }
        }
        if (index != -1){
            uint256 allCollateral = writers[index].collateralAmount.sub(amount);
            uint256 allMintToken = writers[index].OptionsTokenAmount;
            if (_isSufficientCollateral(optionsMap[OptionsToken].options,allCollateral,allMintToken)){
                if (_collateral == address (0)){
                    msg.sender.transfer(amount);
                }else{
                    IERC20 oToken = IERC20(optionsMap[OptionsToken].options.collateralCurrency);
                    oToken.transfer(msg.sender,amount);
                }
                optionsMap[OptionsToken].writers[index].collateralAmount = allCollateral;
            }else{

            }
        }else{

        }
    }
    function exercise()public{
        for (uint keyIndex = _iterate_start();_iterate_valid(keyIndex);keyIndex = _iterate_next(keyIndex)){
            IndexValue storage optionsItem = optionsMap[optionsToken[keyIndex].key];
            _exercise(optionsToken[keyIndex].key,optionsItem);
        }
    }
    function liquidate(address optionsToken,address writer,uint256 amount)public{
        require(_contains(optionsToken),"This OptionsToken does not exist");
        IndexValue storage optionsItem = optionsMap[optionsToken];
        require(!isExpired(optionsItem), "OptionsToken expired");
        int index = -1;
        for(int i=0;i<optionsItem.writers.length;i++){
            if(optionsItem.writers[i].writer == writer){
                index = i;
                break;
            }
        }
        if (index != -1) {
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
            uint256 incentive = _calNumberMulUint(liquidationIncentive,payback);
            _payback = _payback.add(incentive);
            uint256 _transFee;
            (_payback,_transFee) = _calSufficientPayback(_payback,optionsItem.writers[i].collateralAmount);
            optionsItem.writers[index].collateralAmount = optionsItem.writers[index].collateralAmount.sub(_payback);
            optionsItem.writers[index].collateralAmount = optionsItem.writers[index].collateralAmount.sub(_transFee);
            managerFee[optionsItem.options.collateralCurrency] = managerFee[optionsItem.options.collateralCurrency].add(_transFee);
            optionsItem.writers[index].OptionsTokenAmount = optionsItem.writers[index].OptionsTokenAmount.sub(amount);

        }
        /**
            struct OptionsInfo{
        OptionsType	type;
        //Collateral currency address. If this address equals 0, it means that it is Eth;
        address		collateralCurrency;
        //underlying assets type;
        uint32		underlyingAssets;
        uint256		expiration;
        Number      strikePrice;
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
        */
    }
    function burnOptionsToken()public{
    }
    function redeem()public onlyOwner{
    }

    function isETH(IERC20 _ierc20) public pure returns (bool) {
        return _ierc20 == IERC20(0);
    }
    function isCollateralCurrency(address _collateral) public pure returns (bool){
        for (int i=0;i<collateralList.length;i++){
            if (collateralList[i].tokenAddress == _collateral)
                return true;
        }
        return false;
    }
    function _exercise(address tokenAddress,IndexValue storage optionsItem)internal {
        if (isExpired(optionsItem) && !isExercised(optionsItem)) {
            optionsItem.options.isExercised = true;
            //calculate tokenPayback
            uint256 underlyingPrice = _oracle.getUnderlyingPrice(optionsItem.options.underlyingAssets);
            uint256 tokenPayBack = 0;
            if (optionsItem.options.type == OptCall){
                if (underlyingPrice > optionsItem.options.strikePrice){
                    tokenPayBack = underlyingPrice.sub(optionsItem.options.strikePrice);
                }
            }else{
                if ( underlyingPrice < optionsItem.options.strikePrice){
                    tokenPayBack = optionsItem.options.strikePrice.sub(underlyingPrice);
                }
            }
            if (tokenPayBack == 0 ){
                return;
            }
            uint256 collateralPrice = _oracle.getPrice(optionsItem.options.collateralCurrency);
            assert(collateralPrice>0);
            //calculate all pay back collateral and transactionFee
            uint256 allPayback = 0;
            uint256 allTransFee = 0;
            uint256 totalSuply = 0;
            for(int i=0;i<optionsItem.writers.length;i++){
                uint256 _payback = tokenPayBack.mul(optionsItem.writers[i].OptionsTokenAmount);
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
            uint256 tokenPayback = allPayback.div(totalSuply);
            //calculate balance pay back
            IIterableToken iterToken = IIterableToken(tokenAddress);
            IERC20 collateralToken = IERC20(optionsItem.options.collateralCurrency);
            for (uint keyIndex = iterToken.iterate_balance_start();
                iterToken.iterate_balance_valid(keyIndex);
                keyIndex = iterToken.iterate_balance_next()){
                var (addr,balance) = iterToken.iterate_balance_get(keyIndex);
                uint256 _payback = balance.mul(tokenPayback);
                if (isETH(collateralToken)){
                    addr.transfer(_payback);
                }else{
                    collateralToken.transfer(addr,_payback);
                }
            }
            managerFee[optionsItem.options.collateralCurrency] =
                managerFee[optionsItem.options.collateralCurrency].add(allTransFee);
        }
    }
    function _mintOptionsToken(address OptionsToken,address collateral,uint256 amount,uint256 mintOptionsTokenAmount)private returns(bool){
        uint256 allCollateral = 0;
        uint256 allMintToken = 0;
        OptionsWriter[] storage writers = optionsMap[OptionsToken].writers;
        int index = -1;
        for (int i=0;i<writers.length;i++){
            if (writers[i].writer == msg.sender){
                index = i;
                break;
            }
        }
        if(index!= -1){
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
        if (_isSufficientCollateral(optionsMap[OptionsToken].options,allCollateral,allMintToken)){
            if (index == -1){
                optionsMap[OptionsToken].writers.push(OptionsWriter(msg.sender,allCollateral,allMintToken));
            }else{
                optionsMap[OptionsToken].writers[index].collateralAmount = allCollateral;
                optionsMap[OptionsToken].writers[index].OptionsTokenAmount = allMintToken;
            }
        }else{
            return false;
        }
        return true;
    }
    function _burnOptionsToken(address OptionsToken,uint256 burnOptionsTokenAmount)private returns(bool){
        uint256 allCollateral = 0;
        uint256 allMintToken = 0;
        OptionsWriter[] storage writers = optionsMap[OptionsToken].writers;
        int index = -1;
        for (int i=0;i<writers.length;i++){
            if (writers[i].writer == msg.sender){
                index = i;
                break;
            }
        }
        if(index!= -1){
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
    function _isSufficientCollateral(OptionsInfo storage options,uint256 allCollateral,uint256 allMintToken) internal returns (bool){
        uint256 collateralValue = _calCollateralValue(options.collateralCurrency,allCollateral);
        uint256 underlyingPrice = _oracle.getUnderlyingPrice(options.underlyingAssets);
        if (options.type == OptCall){
            uint256 needCollateral = _optionsFormulas.callCollateralPrice(options.strikePrice,underlyingPrice);
            if (needCollateral > collateralValue){
                return false;
            }
        }else{
            uint256 needCollateral = _optionsFormulas.putCollateralPrice(options.strikePrice,underlyingPrice);
            if (needCollateral > collateralValue){
                return false;
            }
        }
        return true;
    }
    function _calSufficientPayback(uint256 payback,uint256 colleteralAmount)internal returns(uint256,uint256){
        uint256 _transFee = _calNumberMulUint(transactionFee,payback);
        uint256 bothPay = payback.add(_transFee);
        if (bothPay>colleteralAmount){
            bothPay = colleteralAmount;
            _transFee = _calNumberMulUint(transactionFee,bothPay);
            payback = allPayback.sub(_transFee);
        }
        return (payback,_transFee);
    }
    function _calCollateralValue(address collateral,uint256 amount)internal returns(uint256){
        uint256 price = _oracle.getPrice(collateral);
        uint256 value = amount.mul(price);
        return value;
    }
    function _calNumberMulUint(Number number,uint256 value) internal returns (uint256){
        uint256 result = number.value.mul(value);
        if (number.exponent > 0) {
            result = result.mul(10**uint256(number.exponent));
        } else {
            result = result.div(10**uint256(-1*number.exponent));
        }
        return result;
    }
    function isExpired(IndexValue storage optionsItem) public view returns (bool){
        return optionsItem.options.expiration<now;
        _;
    }
    function isExercised(IndexValue storage optionsItem) public view returns (bool){
        return optionsItem.options.isExercised;
    }
}
