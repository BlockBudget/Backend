// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface ILendingPool {
    function deposit(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external;

    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) external returns (uint256);
}

contract DefiStaking {
    address public immutable lendingPool;
    address public owner;
    uint256 public constant USER_SHARE = 7000; // 70% (basis points)
    uint256 public constant PROTOCOL_SHARE = 3000; // 30% (basis points)
    uint256 public totalProtocolEarnings;

    struct Stake {
        uint256 amount;
        uint256 depositTime;
    }

    mapping(address => Stake) public stakes;

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount, uint256 interest, uint256 protocolEarnings);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    constructor(address _lendingPool) {
        lendingPool = _lendingPool;
        owner = msg.sender;
    }

    function deposit() external payable {
        require(msg.value > 0, "Deposit amount must be greater than 0");

        Stake storage userStake = stakes[msg.sender];
        userStake.amount += msg.value;
        userStake.depositTime = block.timestamp;

        // Deposit to Aave
        ILendingPool(lendingPool).deposit(address(0), msg.value, address(this), 0);

        emit Deposited(msg.sender, msg.value);
    }

    function withdraw() external {
        Stake storage userStake = stakes[msg.sender];
        require(userStake.amount > 0, "No funds staked");

        // Withdraw from Aave
        uint256 totalBalance = address(this).balance;
        uint256 principal = userStake.amount;
        uint256 interest = totalBalance - principal;

        uint256 userInterest = (interest * USER_SHARE) / 10000;
        uint256 protocolInterest = interest - userInterest;

        // Reset user stake
        userStake.amount = 0;

        // Distribute funds
        totalProtocolEarnings += protocolInterest;
        payable(msg.sender).transfer(principal + userInterest);

        emit Withdrawn(msg.sender, principal, userInterest, protocolInterest);
    }

    function claimProtocolEarnings() external onlyOwner {
        uint256 earnings = totalProtocolEarnings;
        totalProtocolEarnings = 0;
        payable(owner).transfer(earnings);
    }

    function emergencyWithdraw() external onlyOwner {
        ILendingPool(lendingPool).withdraw(address(0), type(uint256).max, address(this));
    }
}
