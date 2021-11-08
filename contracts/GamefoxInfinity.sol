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

library Address {
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }
}

contract GamefoxInfinity is Pausable, ReentrancyGuard {
    address payable public immutable gamefoxToken;

    uint256 public minParchaseAmount = 1000e6;
    uint256 public minWithdrawAmount = 100e6;

    uint256 public inviteRewards;

    uint256 public rewardRate = 0;
    uint256 public rewardDuration = 2592000;
    uint256 public periodFinish;

    uint256 public totalShares;
    uint256 public rewardPerShareStored;
    uint256 public lastUpdateTime;

    struct User {
        address parent;

        uint16 child;

        uint256 amount;
        uint256 shares;
        uint256 rewards;
        uint256 rewardPerSharePaid;
        uint256 inviteRewards;
    }

    mapping(address => User) public users;

    struct FeeRate {
        uint8 child;
        uint8 value;
    }

    FeeRate[] public feeRates;

    struct ParentRate {
        uint256 amount;
        uint8 value;
    }

    ParentRate[] public parentRates;

    event MinParchaseAmountUpdated(uint256 oldValue, uint256 newValue);
    event MinWithdrawAmountUpdated(uint256 oldValue, uint256 newValue);
    event FeeRateUpdated(uint8 indexed child, uint8 oldValue, uint8 newValue);
    event ParentRateUpdated(uint256 indexed amount, uint8 oldValue, uint8 newValue);

    event RewardAdded(uint256 amount);

    event Purchased(address indexed account, address indexed parent, uint256 amount);
    event RewardPaid(address indexed account, uint256 amount);
    event InviteRewardPaid(address indexed account, uint256 amount);

    constructor(address payable gamefoxToken_) {
        gamefoxToken = gamefoxToken_;

        feeRates.push(FeeRate(0, 50));
        feeRates.push(FeeRate(1, 40));
        feeRates.push(FeeRate(5, 30));
        feeRates.push(FeeRate(10, 20));

        parentRates.push(ParentRate(1000e6, 20));
        parentRates.push(ParentRate(1000e6, 10));
        parentRates.push(ParentRate(5000e6, 4));
        parentRates.push(ParentRate(5000e6, 4));
        parentRates.push(ParentRate(10000e6, 4));
        parentRates.push(ParentRate(10000e6, 4));
        parentRates.push(ParentRate(20000e6, 2));
        parentRates.push(ParentRate(20000e6, 2));
    }

    modifier updateReward(address account) {
        rewardPerShareStored = rewardPerShare();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            User storage user = users[account];
            user.rewards = earned(account);
            user.rewardPerSharePaid = rewardPerShareStored;
        }
        _;
    }

    receive() external payable { }

    function setMinParchaseAmount(uint256 value) external onlyOwner {
        uint256 oldValue = minParchaseAmount;
        minParchaseAmount = value;
        emit MinParchaseAmountUpdated(oldValue, value);
    }

    function setMinWithdrawAmount(uint256 value) external onlyOwner {
        uint256 oldValue = minWithdrawAmount;
        minWithdrawAmount = value;
        emit MinWithdrawAmountUpdated(oldValue, value);
    }

    function setFeeRate(uint256 index, uint8 child, uint8 value) external onlyOwner {
        require(index < feeRates.length, "Invalid index");

        FeeRate storage feeRate = feeRates[index];

        uint8 oldValue = feeRate.value;

        feeRate.child = child;
        feeRate.value = value;

        emit FeeRateUpdated(child, oldValue, value);
    }

    function setParentRate(uint256 index, uint256 amount, uint8 value) external onlyOwner {
        require(index < parentRates.length, "Invalid index");

        ParentRate storage parentRate = parentRates[index];
        uint8 oldValue = parentRate.value;

        parentRate.amount = amount;
        parentRate.value = value;

        emit ParentRateUpdated(amount, oldValue, value);
    }

    function maxFeeRate() public view returns (uint256 child, uint256 value) {
        FeeRate memory feeRate = feeRates[feeRates.length - 1];
        return (feeRate.child, feeRate.value);
    }

    function calculateFee(address account, uint256 amount) public view returns (uint256) {
        require(amount >= minWithdrawAmount, "Invalid amount");

        FeeRate memory feeRate = feeRates[0];

        User memory user = users[account];
        if (user.child > 0) {
            for (uint256 i = feeRates.length - 1; i > 0; i--) {
                feeRate = feeRates[i];
                if (user.child >= feeRate.child) {
                    return amount * feeRate.value / 100;
                }
            }
        }

        return amount * feeRate.value / 100;
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }

    function rewardPerShare() public view returns (uint256) {
        if (totalShares == 0) {
            return rewardPerShareStored;
        }
        return rewardPerShareStored + ((lastTimeRewardApplicable() - lastUpdateTime) * rewardRate * 1e18 / totalShares);
    }

    function earned(address account) public view returns (uint256) {
        User memory user = users[account];
        if (user.shares == 0) {
            return 0;
        }
        return user.rewards + (user.shares * rewardPerShare() - user.rewardPerSharePaid) / 1e18;
    }

    function getReward() external whenNotPaused nonReentrant updateReward(_msgSender()) {
        address account = _msgSender();

        User storage user = users[account];

        uint256 amount = user.rewards;
        if (amount > 0) {
            user.shares--;
            user.rewards = 0;

            totalShares--;

            uint256 fee = calculateFee(account, amount);
            Address.sendValue(gamefoxToken, fee);
            Address.sendValue(payable(account), amount - fee);

            emit RewardPaid(account, amount);
        }
    }

    function getInviteReward() external whenNotPaused nonReentrant updateReward(_msgSender()) {
        address account = _msgSender();

        User storage user = users[account];

        uint256 amount = user.inviteRewards;
        if (amount > 0) {
            user.inviteRewards = 0;

            inviteRewards -= amount;

            uint256 fee = calculateFee(account, amount);
            Address.sendValue(gamefoxToken, fee);
            Address.sendValue(payable(account), amount - fee);

            emit InviteRewardPaid(account, amount);
        }
    }

    function purchase(address parent) external payable whenNotPaused nonReentrant updateReward(_msgSender()) {
        address account = _msgSender();
        User storage user = users[account];

        uint256 amount = msg.value;
        require(amount % minParchaseAmount == 0, "Invalid purchase amount");

        user.amount += amount;

        uint256 shares = amount / minParchaseAmount;
        user.shares += shares;

        totalShares += shares;

        _addRewardAmount(amount / 2);

        if (user.parent == address(0) && parent != address(0) && parent != account && users[parent].parent != account) {
            user.parent = parent;
            users[parent].child++;
        }

        parent = user.parent;
        if (parent != address(0)) {
            for (uint256 i = 0; i < parentRates.length; i++ ) {
                if (parent == address(0)) {
                    break;
                }

                ParentRate memory parentRate = parentRates[i];
                if (users[parent].amount >= parentRate.amount && users[parent].shares >= 1) {
                    users[parent].inviteRewards += amount * parentRate.value / 100;
                }

                parent = users[parent].parent;
            }
        }

        emit Purchased(account, parent, amount);
    }

    function _addRewardAmount(uint256 amount) internal {
        inviteRewards += amount;

        if (block.timestamp >= periodFinish) {
            rewardRate = amount / rewardDuration;
        } else {
            uint256 leftover = (periodFinish - block.timestamp) * rewardRate;
            rewardRate = (amount + leftover) / rewardDuration;
        }

        require(rewardRate <= (address(this).balance - inviteRewards) / rewardDuration, "Provided reward too high");

        lastUpdateTime = block.timestamp;

        periodFinish = block.timestamp + rewardDuration;

        emit RewardAdded(amount);
    }
}
