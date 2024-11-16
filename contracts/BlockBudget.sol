// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./TimeLockedLib.sol";
import "./GoalBasedLib.sol";
import "./ContributionLib.sol";

/**
 * @title BlockBudget
 * @notice Main contract integrating all personal finance management features
 * @dev Enhanced with user profile management and contribution handling
 */
contract BlockBudget is Ownable(msg.sender) {
    
    TimeLockedLib.AccountStorage private timeLockedStorage;
    GoalBasedLib.GoalStorage private goalStorage;
    ContributionLib.CampaignStorage private campaignStorage;

    struct UserProfile {
        string name;
        address userAddress;
        bool isRegistered;
        uint256 registrationDate;
    }

    struct Budget {
        string userName;
        address userAddress;
        uint256 timeframe;
        mapping(string => uint256) categoryLimits;
        mapping(string => uint256) categorySpent;
        uint256 totalBudget;
        uint256 startDate;
        uint256 endDate;
        bool isActive;
    }

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

    mapping(address => UserProfile) public userProfiles;
    mapping(address => Budget) public userBudgets;
    mapping(address => Expense[]) public userExpenses;
    mapping(address => Income[]) public userIncomes;
    mapping(address => mapping(address => bool)) public friendsList;

    event UserRegistered(address indexed userAddress, string name, uint256 timestamp);
    event BudgetCreated(address indexed userAddress, string userName, uint256 totalBudget);
    event ExpenseRecorded(address indexed userAddress, uint256 amount, string category);
    event IncomeRecorded(address indexed userAddress, uint256 amount, string source);
    event EmergencyTriggered(address indexed userAddress, string reason);
    event ContributionReceived(bytes32 indexed campaignId, address contributor, uint256 amount);

    modifier onlyRegisteredUser() {
        require(userProfiles[msg.sender].isRegistered, "User not registered");
        _;
    }

    function registerUser(string memory name) external {
        require(!userProfiles[msg.sender].isRegistered, "User already registered");
        require(bytes(name).length > 0, "Name cannot be empty");

        UserProfile storage newProfile = userProfiles[msg.sender];
        newProfile.name = name;
        newProfile.userAddress = msg.sender;
        newProfile.registrationDate = block.timestamp;
        newProfile.isRegistered = true;

        emit UserRegistered(msg.sender, name, block.timestamp);
    }

    function createTimeLockedAccount(
        TimeLockedLib.AccountType accountType,
        TimeLockedLib.InterestType interestType,
        uint256 lockDuration,
        uint256 initialDeposit
    ) external onlyRegisteredUser {
        TimeLockedLib.createAccount(
            timeLockedStorage,
            msg.sender,
            accountType,
            interestType,
            lockDuration,
            initialDeposit
        );
    }

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
    ) external onlyRegisteredUser returns (bytes32) {
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

    function createCampaign(
        string memory name,
        string memory description,
        uint256 targetAmount,
        uint256 duration,
        bool isPrivate
    ) external onlyRegisteredUser returns (bytes32) {
        return ContributionLib.createCampaign(
            campaignStorage,
            name,
            description,
            targetAmount,
            duration,
            isPrivate
        );
    }

    function contributeToCompaign(bytes32 campaignId) external payable onlyRegisteredUser returns (bool) {
        require(msg.value > 0, "Contribution amount must be positive");
        bool success = ContributionLib.contribute(
            campaignStorage,
            campaignId
        );
        require(success, "Contribution failed");
        emit ContributionReceived(campaignId, msg.sender, msg.value);
        return true;
    }

    function createBudget(
        uint256 _timeframe,
        uint256 _totalBudget,
        string[] memory _categories,
        uint256[] memory _limits
    ) external onlyRegisteredUser {
        require(_categories.length == _limits.length, "Categories and limits mismatch");
        UserProfile storage profile = userProfiles[msg.sender];
        
        Budget storage newBudget = userBudgets[msg.sender];
        newBudget.userName = profile.name;
        newBudget.userAddress = msg.sender;
        newBudget.timeframe = _timeframe;
        newBudget.totalBudget = _totalBudget;
        newBudget.startDate = block.timestamp;
        newBudget.endDate = block.timestamp + _timeframe;
        newBudget.isActive = true;
        
        for (uint i = 0; i < _categories.length; i++) {
            newBudget.categoryLimits[_categories[i]] = _limits[i];
        }
        
        emit BudgetCreated(msg.sender, profile.name, _totalBudget);
    }

    function getUserProfile(address user) external view returns (
        string memory name,
        address userAddress,
        uint256 registrationDate,
        bool isRegistered
    ) {
        UserProfile storage profile = userProfiles[user];
        return (
            profile.name,
            profile.userAddress,
            profile.registrationDate,
            profile.isRegistered
        );
    }

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
        string memory description,
        address owner,
        uint256 targetAmount,
        uint256 deadline,
        uint256 totalContributed,
        uint256 contributorCount,
        bool isActive,
        bool isPrivate
    ) {
        return ContributionLib.getCampaignDetails(
            campaignStorage,
            campaignId
        );
    }
}