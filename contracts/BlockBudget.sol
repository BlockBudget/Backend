// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./TimeLockedLib.sol";
import "./GoalBasedLib.sol";
import "./ContributionLib.sol";

/**
 * @title BlockBudget
 * @notice Main contract integrating all personal finance management features
 */
contract BlockBudget is Ownable(msg.sender) {
    // Library storage
    TimeLockedLib.AccountStorage private timeLockedStorage;
    GoalBasedLib.GoalStorage private goalStorage;
    ContributionLib.CampaignStorage private campaignStorage;

    // Budget structure
    struct Budget {
        uint256 timeframe;
        mapping(string => uint256) categoryLimits;
        mapping(string => uint256) categorySpent;
        uint256 totalBudget;
        uint256 startDate;
        uint256 endDate;
        bool isActive;
    }

    // Expense and Income structures
    struct Expense {
        uint256 amount;
        string category;
        uint256 date;
        string description;
        string attachmentHash;
        bool isRecurring;
        uint256 recurringInterval;
    }

    struct Income {
        uint256 amount;
        string source;
        uint256 date;
        string category;
        bool isRecurring;
        uint256 recurringInterval;
    }

    // Mappings
    mapping(address => Budget) public userBudgets;
    mapping(address => Expense[]) public userExpenses;
    mapping(address => Income[]) public userIncomes;
    mapping(address => mapping(address => bool)) public friendsList;

    // Events
    event BudgetCreated(address indexed userAddress, uint256 totalBudget);
    event ExpenseRecorded(address indexed userAddress, uint256 amount, string category);
    event IncomeRecorded(address indexed userAddress, uint256 amount, string source);
    event EmergencyTriggered(address indexed userAddress, string reason);

    // Time-Locked Savings Functions
    function createTimeLockedAccount(
        TimeLockedLib.AccountType accountType,
        TimeLockedLib.InterestType interestType,
        uint256 lockDuration,
        uint256 initialDeposit
    ) external {
        TimeLockedLib.createAccount(
            timeLockedStorage,
            msg.sender,
            accountType,
            interestType,
            lockDuration,
            initialDeposit
        );
    }

    function depositToTimeLockedAccount(uint256 amount) external {
        TimeLockedLib.deposit(
            timeLockedStorage,
            msg.sender,
            amount
        );
    }

    function withdrawFromTimeLockedAccount(uint256 amount) external {
        TimeLockedLib.withdraw(
            timeLockedStorage,
            msg.sender,
            amount
        );
    }

    function calculateTimeLockedInterest() external {
        TimeLockedLib.calculateInterest(
            timeLockedStorage,
            msg.sender
        );
    }

    // Goal-Based Savings Functions
    function createSavingsGoal(
        string memory name,
        uint256 targetAmount,
        uint256 deadline,
        GoalBasedLib.GoalType goalType,
        GoalBasedLib.SavingFrequency frequency,
        uint256 minContributionAmount,
        bool isFlexible,
        bool autoContribute,
        uint256 penaltyRate
    ) external returns (bytes32) {
        return GoalBasedLib.createGoal(
            goalStorage,
            name,
            targetAmount,
            deadline,
            goalType,
            frequency,
            minContributionAmount,
            isFlexible,
            autoContribute,
            penaltyRate
        );
    }

    function addGoalMilestone(
        bytes32 goalId,
        string memory description,
        uint256 targetAmount,
        uint256 deadline,
        uint256 rewardAmount
    ) external returns (uint256) {
        return GoalBasedLib.defineMilestone(
            goalStorage,
            goalId,
            description,
            targetAmount,
            deadline,
            rewardAmount
        );
    }

    function checkGoalMilestone(bytes32 goalId, uint256 milestoneIndex) 
        external 
        returns (bool) 
    {
        return GoalBasedLib.checkMilestoneProgress(
            goalStorage,
            goalId,
            milestoneIndex
        );
    }

    function withdrawFromGoal(
        bytes32 goalId,
        uint256 amount,
        bool isEmergency
    ) external returns (uint256) {
        return GoalBasedLib.processWithdrawal(
            goalStorage,
            goalId,
            amount,
            isEmergency
        );
    }

    // Crowdfunding Campaign Functions
    function createCampaign(
        string memory name,
        uint256 targetAmount,
        uint256 duration
    ) external returns (bytes32) {
        return ContributionLib.createCampaign(
            campaignStorage,
            name,
            targetAmount,
            duration
        );
    }

    function contributeToCompaign(bytes32 campaignId) 
        external 
        payable 
        returns (bool) 
    {
        return ContributionLib.contribute(
            campaignStorage,
            campaignId
        );
    }

    function endCampaign(bytes32 campaignId) external returns (bool) {
        return ContributionLib.endCampaign(
            campaignStorage,
            campaignId
        );
    }

    // Budget Management Functions
    function createBudget(
        uint256 _timeframe,
        uint256 _totalBudget,
        string[] memory _categories,
        uint256[] memory _limits
    ) external {
        require(_categories.length == _limits.length, "Categories and limits mismatch");
        
        Budget storage newBudget = userBudgets[msg.sender];
        newBudget.timeframe = _timeframe;
        newBudget.totalBudget = _totalBudget;
        newBudget.startDate = block.timestamp;
        newBudget.endDate = block.timestamp + _timeframe;
        newBudget.isActive = true;
        
        for (uint i = 0; i < _categories.length; i++) {
            newBudget.categoryLimits[_categories[i]] = _limits[i];
        }
        
        emit BudgetCreated(msg.sender, _totalBudget);
    }

    // View Functions
    function getTimeLockedAccountDetails(address user) external view returns (
        uint256 balance,
        uint256 accruedInterest,
        uint256 lockEndTime,
        bool isActive
    ) {
        return TimeLockedLib.getAccountDetails(
            timeLockedStorage,
            user
        );
    }

    function getGoalDetails(bytes32 goalId) external view returns (
        string memory name,
        uint256 targetAmount,
        uint256 currentAmount,
        uint256 deadline,
        GoalBasedLib.GoalStatus status,
        uint256 milestoneCount
    ) {
        return GoalBasedLib.getGoalDetails(
            goalStorage,
            goalId
        );
    }

    function getCampaignDetails(bytes32 campaignId) external view returns (
        string memory name,
        address owner,
        uint256 targetAmount,
        uint256 deadline,
        uint256 totalContributed,
        uint256 contributorCount,
        bool isActive
    ) {
        return ContributionLib.getCampaignDetails(
            campaignStorage,
            campaignId
        );
    }
}
