pragma solidity ^0.4.26;
import "./Ownable.sol";
import "./IERC20.sol";
import "./SafeMath.sol";
import "./IIterableToken.sol";
contract BalanceMapping is IIterableToken
{
    itmap internal _balances;
    struct itmap
    {
        mapping(address => IndexValue) data;
        KeyFlag[] keys;
        uint size;
    }
    struct IndexValue { uint keyIndex; uint256 value; }
    struct KeyFlag { address key; bool deleted; }
    function insert(address key, uint256 value) internal returns (bool)
    {
        uint keyIndex = _balances.data[key].keyIndex;
        _balances.data[key].value = value;
        if (keyIndex > 0)
           return true;
        else
        {
            keyIndex = _balances.keys.length++;
            _balances.data[key].keyIndex = keyIndex + 1;
            _balances.keys[keyIndex].key = key;
            _balances.size++;
            return false;
        }
    }
    function remove(address key)internal returns (bool)
    {
        uint keyIndex = _balances.data[key].keyIndex;
        if (keyIndex == 0)
            return false;
        delete _balances.data[key];
        _balances.keys[keyIndex - 1].deleted = true;
        _balances.size --;
        return true;
    }
    function contains(address key)public view returns (bool)
    {
        return _balances.data[key].keyIndex > 0;
    }
    function iterate_balance_start()public view returns (uint)
    {
        uint keyIndex = uint(-1);
        return iterate_balance_next(keyIndex);
    }
    function iterate_balance_valid(uint keyIndex)public view returns (bool)
    {
        return keyIndex < _balances.keys.length;
    }
    function iterate_balance_next(uint keyIndex)public view returns (uint)
    {
        keyIndex++;
        while (keyIndex < _balances.keys.length && _balances.keys[keyIndex].deleted)
            keyIndex++;
        return keyIndex;
    }
    function iterate_balance_get(uint keyIndex)public view returns (address key, uint256 value)
    {
        key = _balances.keys[keyIndex].key;
        value = _balances.data[key].value;
    }
}
contract Expration is Ownable {

    uint256  private _expiration;

    modifier notExpired() {
        require(now < _expiration,"Token is Expired");
        _;
    }

    modifier isExpired() {
        require(now >= _expiration,"Token is not Expired");
        _;
    }

    /// @notice function Emergency situation that requires
    /// @notice contribution period to stop or not.
    function setExpration(uint256 expiration)
    public
    onlyOwner
    {
        _expiration = expiration;
    }
    function getExpration()public view returns (uint256) {
        return _expiration;
    }
}
contract Managerable is Expration {

    address private _managerAddress;

    modifier onlyManager() {
        require(_managerAddress == msg.sender,"Managerable: caller is not the Manager");
        _;
    }
    /// @notice function Emergency situation that requires
    /// @notice contribution period to stop or not.
    function setManager(address managerAddress)
    public
    onlyOwner
    {
        _managerAddress = managerAddress;
    }
    function getManager()public view returns (address) {
        return _managerAddress;
    }
}
/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20Mintable}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.zeppelin.solutions/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * We have followed general OpenZeppelin guidelines: functions revert instead
 * of returning `false` on failure. This behavior is nonetheless conventional
 * and does not conflict with the expectations of ERC20 applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IERC20-approve}.
 */
contract OptionsToken is Managerable, IERC20,BalanceMapping  {
    using SafeMath for uint256;
    string public name = "OptionsToken";
    string public symbol = "OptionsToken";
    uint8 public constant decimals = 18;
    


    mapping (address => mapping (address => uint256)) private _allowances;

    uint256 private _totalSupply = 0;

    constructor (uint256 expiration,string tokenName) public{
        setExpration(expiration);
        setManager(msg.sender);
        name = tokenName;
    }
    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }


    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view returns (uint256) {
        return _balances.data[account].value;
    }
    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount)
    public
    notExpired
    returns (bool)
    {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount)
    public
    notExpired
    returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20};
     *
     * Requirements:
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for `sender`'s tokens of at least
     * `amount`.
     */
    function transferFrom(address sender, address recipient, uint256 amount)
    public
    notExpired
    returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, _allowances[sender][msg.sender].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue)
    public
    notExpired
    returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender].add(addedValue));
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue)
    public
    notExpired
    returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    function burn(uint256 amount) public notExpired onlyManager returns (bool){
        _burn(msg.sender, amount);
        return true;
    }
    function mint(address account,uint256 amount) public notExpired onlyManager returns (bool){
        _mint(account,amount);
        return true;
    }
    /**
     * @dev add `recipient`'s balance to iterable mapping balances.
     */
    function _addBalance(address recipient, uint256 amount) internal {
        require(recipient != address(0), "ERC20: transfer to the zero address");

        uint256 balance = _balances.data[recipient].value;
        balance = balance.add(amount);

        insert(recipient,balance);
    }
    /**
     * @dev add `recipient`'s balance to iterable mapping balances.
     */
    function _subBalance(address recipient, uint256 amount) internal {
        require(recipient != address(0), "ERC20: transfer to the zero address");

        uint256 balance = _balances.data[recipient].value;
        balance = balance.sub(amount);

        if (balance > 0){
            insert(recipient,balance);
        }else{
            remove(recipient);
        }
    }
    /**
     * @dev Moves tokens `amount` from `sender` to `recipient`.
     *
     * This is internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        _subBalance(sender,amount);
        _addBalance(recipient,amount);
        emit Transfer(sender, recipient, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements
     *
     * - `to` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: mint to the zero address");

        _totalSupply = _totalSupply.add(amount);
        _addBalance(account,amount);
        emit Transfer(address(0), account, amount);
    }

    /**
    * @dev Destroys `amount` tokens from `account`, reducing the
    * total supply.
    *
    * Emits a {Transfer} event with `to` set to the zero address.
    *
    * Requirements
    *
    * - `account` cannot be the zero address.
    * - `account` must have at least `amount` tokens.
    */
    function _burn(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: burn from the zero address");

        _subBalance(account,amount);
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner`s tokens.
     *
     * This is internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`.`amount` is then deducted
     * from the caller's allowance.
     *
     * See {_burn} and {_approve}.
     */
    function _burnFrom(address account, uint256 amount) internal {
        _burn(account, amount);
        _approve(account, msg.sender, _allowances[account][msg.sender].sub(amount, "ERC20: burn amount exceeds allowance"));
    }
}
