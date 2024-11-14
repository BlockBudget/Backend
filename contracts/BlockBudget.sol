// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./ContributionLib.sol";
import "./GoalBasedLib.sol";
import "./TimeLockedLib.sol";

/**
 * @title BlockBudget
 * @notice Main contract integrating all personal finance management features
 */
contract BlockBudget is Ownable{
    using ContributionLib for ContributionLib.ContributionData;
    using GoalBasedLib for GoalBasedLib.GoalData;
    using TimeLockedLib for TimeLockedLib.TimeLockedData;

    // Libraries state data
    ContributionLib.ContributionData private contributionData;
    GoalBasedLib.GoalData private goalData;
    TimeLockedLib.TimeLockedData private timeLockedData;

    // User profile structure
    struct UserProfile {
        string username;
        bytes32 emailHash;
        address[] wallets;
        string preferredCurrency;
        uint8 privacySettings; // 0: PUBLIC, 1: PRIVATE, 2: FRIENDS_ONLY
        string languagePreference;
        string timeZone;
        bool isActive;
        mapping(address => bool) authorizedWallets;
    }

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

    // Expense structure
    struct Expense {
        uint256 amount;
        string category;
        uint256 date;
        string description;
        string attachmentHash;
        bool isRecurring;
        uint256 recurringInterval;
    }

    // Income structure
    struct Income {
        uint256 amount;
        string source;
        uint256 date;
        string category;
        bool isRecurring;
        uint256 recurringInterval;
    }

    // Mappings
    mapping(address => UserProfile) public userProfiles;
    mapping(address => Budget) public userBudgets;
    mapping(address => Expense[]) public userExpenses;
    mapping(address => Income[]) public userIncomes;
    mapping(address => mapping(address => bool)) public friendsList;

    // Events
    event UserRegistered(address indexed userAddress, string username);
    event BudgetCreated(address indexed userAddress, uint256 totalBudget);
    event ExpenseRecorded(address indexed userAddress, uint256 amount, string category);
    event IncomeRecorded(address indexed userAddress, uint256 amount, string source);
    event GoalLinked(address indexed userAddress, string goalName);
    event EmergencyTriggered(address indexed userAddress, string reason);

    constructor() {}

    // User Profile Management Functions
    function registerUser(
        string memory _username,
        string memory _email,
        string memory _preferredCurrency,
        string memory _languagePreference,
        string memory _timeZone
    ) external {
        require(!userProfiles[msg.sender].isActive, "User already registered");
        
        UserProfile storage newProfile = userProfiles[msg.sender];
        newProfile.username = _username;
        newProfile.emailHash = keccak256(abi.encodePacked(_email));
        newProfile.preferredCurrency = _preferredCurrency;
        newProfile.languagePreference = _languagePreference;
        newProfile.timeZone = _timeZone;
        newProfile.isActive = true;
        
        address;
        initialWallet[0] = msg.sender;
        newProfile.wallets = initialWallet;
        newProfile.authorizedWallets[msg.sender] = true;
        
        emit UserRegistered(msg.sender, _username);
    }

    function updatePrivacySettings(uint8 _setting) external {
        require(_setting <= 2, "Invalid privacy setting");
        require(userProfiles[msg.sender].isActive, "User not registered");
        userProfiles[msg.sender].privacySettings = _setting;
    }

    // Budget Management Functions
    function createBudget(
        uint256 _timeframe,
        uint256 _totalBudget,
        string[] memory _categories,
        uint256[] memory _limits
    ) external {
        require(userProfiles[msg.sender].isActive, "User not registered");
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

    // Expense Tracking Functions
    function recordExpense(
        uint256 _amount,
        string memory _category,
        string memory _description,
        string memory _attachmentHash,
        bool _isRecurring,
        uint256 _recurringInterval
    ) external {
        require(userProfiles[msg.sender].isActive, "User not registered");
        require(userBudgets[msg.sender].isActive, "No active budget");
        
        Budget storage budget = userBudgets[msg.sender];
        require(budget.categoryLimits[_category] >= 
            budget.categorySpent[_category] + _amount, 
            "Exceeds category limit"
        );
        
        Expense memory newExpense = Expense({
            amount: _amount,
            category: _category,
            date: block.timestamp,
            description: _description,
            attachmentHash: _attachmentHash,
            isRecurring: _isRecurring,
            recurringInterval: _recurringInterval
        });
        
        userExpenses[msg.sender].push(newExpense);
        budget.categorySpent[_category] += _amount;
        
        emit ExpenseRecorded(msg.sender, _amount, _category);
    }

    // Income Management Functions
    function recordIncome(
        uint256 _amount,
        string memory _source,
        string memory _category,
        bool _isRecurring,
        uint256 _recurringInterval
    ) external {
        require(userProfiles[msg.sender].isActive, "User not registered");
        
        Income memory newIncome = Income({
            amount: _amount,
            source: _source,
            date: block.timestamp,
            category: _category,
            isRecurring: _isRecurring,
            recurringInterval: _recurringInterval
        });
        
        userIncomes[msg.sender].push(newIncome);
        
        emit IncomeRecorded(msg.sender, _amount, _source);
    }

    // Financial Goals Integration Functions
    function createSavingsGoal(
        string memory _goalName,
        uint256 _targetAmount,
        uint256 _deadline,
        uint8 _goalType,
        uint8 _savingFrequency,
        uint256 _minContribution
    ) external {
        require(userProfiles[msg.sender].isActive, "User not registered");
        
        goalData.createGoal(
            msg.sender,
            _goalName,
            _targetAmount,
            _deadline,
            _goalType,
            _savingFrequency,
            _minContribution
        );
        
        emit GoalLinked(msg.sender, _goalName);
    }

    function createTimeLockedSavings(
        uint8 _accountType,
        uint256 _lockDuration,
        uint8 _interestType,
        uint256 _interestRate,
        uint256 _minDeposit
    ) external {
        require(userProfiles[msg.sender].isActive, "User not registered");
        
        timeLockedData.createAccount(
            msg.sender,
            _accountType,
            _lockDuration,
            _interestType,
            _interestRate,
            _minDeposit
        );
    }

    function createContributionGroup(
        string memory _groupName,
        uint8 _contributionType,
        uint256 _minContribution,
        uint256 _maxMembers,
        uint8 _frequency,
        uint256 _frequencyCount
    ) external {
        require(userProfiles[msg.sender].isActive, "User not registered");
        
        contributionData.createGroup(
            msg.sender,
            _groupName,
            _contributionType,
            _minContribution,
            _maxMembers,
            _frequency,
            _frequencyCount
        );
    }

    // Emergency Functions
    function triggerEmergency(string memory _reason) external onlyOwner {
        _pause();
        emit EmergencyTriggered(msg.sender, _reason);
    }

    function resolveEmergency() external onlyOwner {
        _unpause();
    }

    // View Functions
    function getUserProfile(address _user) external view returns (
        string memory username,
        string memory preferredCurrency,
        uint8 privacySettings,
        string memory languagePreference,
        bool isActive
    ) {
        UserProfile storage profile = userProfiles[_user];
        return (
            profile.username,
            profile.preferredCurrency,
            profile.privacySettings,
            profile.languagePreference,
            profile.isActive
        );
    }

    function getBudgetSummary(address _user) external view returns (
        uint256 timeframe,
        uint256 totalBudget,
        uint256 startDate,
        uint256 endDate,
        bool isActive
    ) {
        Budget storage budget = userBudgets[_user];
        return (
            budget.timeframe,
            budget.totalBudget,
            budget.startDate,
            budget.endDate,
            budget.isActive
        );
    }
}
