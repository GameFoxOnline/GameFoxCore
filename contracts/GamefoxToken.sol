// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        _transferOwnership(_msgSender());
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

abstract contract Pausable is Ownable {
    bool private _paused;

    event Paused(address account);
    event Unpaused(address account);

    constructor() {
        _paused = false;
    }

    modifier whenNotPaused() {
        require(!paused(), "Pausable: paused");
        _;
    }

    modifier whenPaused() {
        require(paused(), "Pausable: not paused");
        _;
    }

    function paused() public view virtual returns (bool) {
        return _paused;
    }

    function pause() public virtual whenNotPaused onlyOwner {
        _paused = true;
        emit Paused(_msgSender());
    }

    function unpause() public virtual whenPaused onlyOwner {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

interface IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);

    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 value);
}

contract ERC20 is IERC20, Pausable {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual override returns (uint8) {
        return 6;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(_msgSender(), spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);

        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        unchecked {
            _approve(sender, _msgSender(), currentAllowance - amount);
        }

        return true;
    }

    function _approve(address owner, address spender, uint256 amount) internal virtual whenNotPaused {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(address sender, address recipient, uint256 amount) internal virtual whenNotPaused {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[sender] = senderBalance - amount;
        }
        _balances[recipient] += amount;

        emit Transfer(sender, recipient, amount);
    }

    function _mint(address account, uint256 amount) internal virtual whenNotPaused {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual {}
}

library Address {
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }
}

interface IGamefoxInfinity {
    function users(address account) external view returns (address parent, uint16 child, uint256 amount, uint256 shares, uint256 rewards, uint256 rewardPerSharePaid, uint256 invitationRewards);

    function maxFeeRate() external view returns (uint256 child, uint256 value);
    function calculateFee(address account, uint256 amount) external view returns (uint256);
}

contract GamefoxToken is ERC20, ReentrancyGuard {
    IGamefoxInfinity public gamefoxInfinity;

    uint256 public rewardPerToken;

    uint256 public lastRound;

    struct Round {
        uint256 supply;
        uint256 sold;
        uint256 price;
    }

    mapping(uint256 => Round) public rounds;

    mapping(address => mapping(uint256 => uint256)) public purchased;
    mapping(address => uint256) public lastRewardPerToken;

    event GamefoxInfinityUpdated(address indexed oldValue, address newValue);
    event MaxPurchaseAmountUpdated(uint256 oldValue, uint256 newValue);
    event NewRoundStarted(uint256 indexed round, uint256 supply, uint256 price);

    event RewardAdded(uint256 amount);

    event Released(address indexed to, uint256 amount);
    event Purchased(address indexed account, uint256 amount);

    constructor() ERC20("Gamefox Token", "GFT") {
    }

    receive() external payable {
        _addRewardAmount(msg.value);
    }

    function setGamefoxInfinity(address value) external onlyOwner {
        require(value != address(0), "New value is the zero address");

        address oldValue = address(gamefoxInfinity);
        gamefoxInfinity = IGamefoxInfinity(value);

        emit GamefoxInfinityUpdated(oldValue, value);
    }

    function newRound(uint256 supply, uint256 price) external onlyOwner {
        require(supply > 0 && price > 0, "Supply or price must be greater than zero");

        lastRound++;
        rounds[lastRound] = Round(supply, 0, price);

        emit NewRoundStarted(lastRound, supply, price);
    }

    function releasable(address to) public view returns (uint256) {
        uint256 amount = balanceOf(to);
        if (amount == 0 || rewardPerToken == 0) {
            return 0;
        }
        return amount * (rewardPerToken - lastRewardPerToken[to]) / 1e18;
    }

    function release(address to) public whenNotPaused {
        uint256 amount = releasable(to);
        if (amount > 0) {
            _verifyChild(to);

            uint256 fee = gamefoxInfinity.calculateFee(to, amount);
            _addRewardAmount(fee);

            Address.sendValue(payable(to), amount - fee);

            emit Released(to, amount);
        }

        lastRewardPerToken[to] = rewardPerToken;
    }

    function purchase(uint256 amount) external payable whenNotPaused nonReentrant {
        address account = _msgSender();

        Round storage round = rounds[lastRound];
        require(amount <= round.supply - round.sold, "Insufficient supply");

        uint256 weiAmount = amount * round.price / 1e6;
        require(msg.value >= weiAmount, "Underpayment");

        round.sold += amount;

        if (lastRound <= 1) {
            Address.sendValue(payable(owner()), weiAmount);
        } else {
            _verifyChild(account);

            Address.sendValue(payable(owner()), weiAmount / 2);
        }

        _mint(account, amount);

        emit Purchased(account, amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override {
        if (from != address(0) && from != address(this)) {
            release(from);
        }
        if (to != address(0) && to != address(this)) {
            release(to);
        }
        super._beforeTokenTransfer(from, to, amount);
    }

    function _addRewardAmount(uint256 amount) internal {
        rewardPerToken += amount * 1e18 / totalSupply();
        emit RewardAdded(amount);
    }

    function _verifyChild(address account) internal view {
        (uint256 requiredChildAmount,) = gamefoxInfinity.maxFeeRate();

        (, uint16 childAmount, , , , ,) = gamefoxInfinity.users(account);
        require(childAmount >= requiredChildAmount, "Too few child");
    }
}
