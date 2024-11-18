// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title GoalBasedSavingsLib
 * @notice Library for managing goal-based savings targets and milestones
 * @dev Implements functionality for personal and group savings goals with optimized gas usage
 */
library GoalBasedLib {
    
    enum GoalType { PERSONAL, GROUP, CHALLENGE }
    enum GoalStatus { ACTIVE, PAUSED, COMPLETED, CANCELLED }
    enum SavingFrequency { DAILY, WEEKLY, MONTHLY, FLEXIBLE }
    
    struct Milestone {
        string description;
        uint256 targetAmount;
        uint256 deadline;
        uint256 rewardAmount;
        uint256 completedAt;
        bool isCompleted;   
    }
    
    struct Goal {
        string name;
        address owner;   
        uint256 targetAmount;
        uint256 currentAmount;
        uint256 deadline;
        uint256 createdAt;
        uint256 minContributionAmount;
        uint256 penaltyRate;
        uint256 milestoneCount;
        GoalType goalType;
        GoalStatus status;
        SavingFrequency frequency;
        bool isFlexible;
        bool autoContribute;
        mapping(uint256 => Milestone) milestones;
        mapping(address => uint256[]) contributions;
        mapping(address => uint256[]) withdrawals;
    }
    
    struct GoalStorage {
        mapping(bytes32 => Goal) goals;
        mapping(address => bytes32[]) userGoals;
        uint256 totalGoals;
    }
    
    event GoalCreated(
        bytes32 indexed goalId,
        address indexed owner,
        string name,
        uint256 targetAmount,
        uint256 deadline
    );
    
    event ContributionMade(
        bytes32 indexed goalId,
        address indexed contributor,
        uint256 amount
    );
    
    event MilestoneAchieved(
        bytes32 indexed goalId,
        uint256 milestoneIndex,
        uint256 timestamp
    );
    
    event RewardDistributed(
        bytes32 indexed goalId,
        address indexed recipient,
        uint256 amount
    );
    
    event GoalModified(
        bytes32 indexed goalId,
        uint256 newTarget,
        uint256 newDeadline
    );
    
    event WithdrawalProcessed(
        bytes32 indexed goalId,
        address indexed withdrawer,
        uint256 amount,
        uint256 penalty
    );

    event WithdrawalProcessed(
        bytes32 indexed goalId,
        address indexed withdrawer,
        uint256 amount,
        uint256 penalty,
        uint256 timestamp
    );
    
    event GoalCompleted(bytes32 indexed goalId, uint256 timestamp);
    
    event EmergencyAction(
        bytes32 indexed goalId,
        string actionType,
        string reason
    );
    
    error InvalidTargetAmount();
    error InvalidDeadline();
    error NotGoalOwner();
    error InvalidMilestoneDeadline();
    error GoalNotActive();
    error InsufficientFunds();
    error ZeroAddress();
    error InsufficientBalance();
    error WithdrawalAmountTooLow();
    error GoalLocked();
    error WithdrawalFailed();
    
    function createGoal(
        GoalStorage storage self,
        string calldata name,   
        uint256 targetAmount,
        uint256 deadline,
        GoalType goalType,
        SavingFrequency frequency,
        uint256 minContributionAmount,
        bool isFlexible,
        bool autoContribute,
        uint256 penaltyRate
    ) external returns (bytes32) {
        if (targetAmount == 0) revert InvalidTargetAmount();
        if (deadline <= block.timestamp) revert InvalidDeadline();
        if (msg.sender == address(0)) revert ZeroAddress();
        
        bytes32 goalId = keccak256(
            abi.encodePacked(
                name,
                block.timestamp,
                msg.sender
            )
        );
        
        Goal storage newGoal = self.goals[goalId];
        
        newGoal.name = name;
        newGoal.owner = msg.sender;   
        newGoal.targetAmount = targetAmount;
        newGoal.deadline = deadline;
        newGoal.createdAt = block.timestamp;
        newGoal.goalType = goalType;
        newGoal.frequency = frequency;
        newGoal.minContributionAmount = minContributionAmount;
        newGoal.isFlexible = isFlexible;
        newGoal.autoContribute = autoContribute;
        newGoal.penaltyRate = penaltyRate;
        newGoal.status = GoalStatus.ACTIVE;
        
        unchecked {
            self.totalGoals++;
        }
        
        self.userGoals[msg.sender].push(goalId);
        
        emit GoalCreated(
            goalId,
            msg.sender,
            name,
            targetAmount,
            deadline
        );
        
        return goalId;
    }
    
    function defineMilestone(
        GoalStorage storage self,
        bytes32 goalId,
        string calldata description,   
        uint256 targetAmount,
        uint256 deadline,
        uint256 rewardAmount
    ) external returns (uint256) {
        Goal storage goal = self.goals[goalId];
        if (goal.owner != msg.sender) revert NotGoalOwner();
        if (deadline > goal.deadline) revert InvalidMilestoneDeadline();
        
        uint256 milestoneIndex = goal.milestoneCount;
        Milestone storage milestone = goal.milestones[milestoneIndex];
        
        milestone.description = description;
        milestone.targetAmount = targetAmount;
        milestone.deadline = deadline;
        milestone.rewardAmount = rewardAmount;
         
        unchecked {
            goal.milestoneCount++;
        }
        
        return milestoneIndex;
    }
    
    function checkMilestoneProgress(
        GoalStorage storage self,
        bytes32 goalId,
        uint256 milestoneIndex
    ) external returns (bool) {
        Goal storage goal = self.goals[goalId];
        Milestone storage milestone = goal.milestones[milestoneIndex];
        
        if (!milestone.isCompleted && 
            goal.currentAmount >= milestone.targetAmount) {
            milestone.isCompleted = true;
            milestone.completedAt = block.timestamp;
            
            emit MilestoneAchieved(goalId, milestoneIndex, block.timestamp);
            return true;
        }
        return false;
    }
    
    function calculateProgress(
        GoalStorage storage self,
        bytes32 goalId
    ) external view returns (
        uint256 percentageComplete,
        uint256 remaining,
        uint256 timeLeft
    ) {
        Goal storage goal = self.goals[goalId];
        
        unchecked {
            percentageComplete = (goal.currentAmount * 100) / goal.targetAmount;
            remaining = goal.targetAmount - goal.currentAmount;
            timeLeft = goal.deadline > block.timestamp ? 
                      goal.deadline - block.timestamp : 0;
        }
    }
    
    function trackSavingRate(
        GoalStorage storage self,
        bytes32 goalId
    ) external view returns (uint256) {
        Goal storage goal = self.goals[goalId];
        if (block.timestamp <= goal.createdAt) return 0;
        
        unchecked {
            return (goal.currentAmount * 1e18) / 
                   (block.timestamp - goal.createdAt);
        }
    }
    
    function verifyCompletion(
        GoalStorage storage self,
        bytes32 goalId
    ) external returns (bool) {
        Goal storage goal = self.goals[goalId];
        
        if (goal.currentAmount >= goal.targetAmount) {
            goal.status = GoalStatus.COMPLETED;
            emit GoalCompleted(goalId, block.timestamp);
            return true;
        }
        return false;
    }
    
    function modifyGoal(
        GoalStorage storage self,
        bytes32 goalId,
        uint256 newTarget,
        uint256 newDeadline
    ) external {
        Goal storage goal = self.goals[goalId];
        if (goal.owner != msg.sender) revert NotGoalOwner();
        if (goal.status != GoalStatus.ACTIVE) revert GoalNotActive();
        
        if (newTarget > 0) goal.targetAmount = newTarget;
        if (newDeadline > block.timestamp) goal.deadline = newDeadline;
        
        emit GoalModified(goalId, newTarget, newDeadline);
    }
    
    function processWithdrawal(
        GoalStorage storage self,
        bytes32 goalId,
        uint256 amount,
        bool isEmergency
    ) external returns (uint256) {
        Goal storage goal = self.goals[goalId];
        if (goal.owner != msg.sender) revert NotGoalOwner();
        if (amount > goal.currentAmount) revert InsufficientFunds();
        
        uint256 penalty = 0;
        if (!isEmergency && goal.status == GoalStatus.ACTIVE) {
            unchecked {
                penalty = (amount * goal.penaltyRate) / 10000;
            }
        }
        
        unchecked {
            uint256 netWithdrawal = amount - penalty;
            goal.currentAmount -= amount;
            goal.withdrawals[msg.sender].push(netWithdrawal);
            
            emit WithdrawalProcessed(
                goalId,
                msg.sender,
                netWithdrawal,
                penalty
            );
            
            return netWithdrawal;
        }
    }
    
    function emergencyAction(
        GoalStorage storage self,
        bytes32 goalId,
        string calldata actionType,   
        string calldata reason       
    ) external {
        Goal storage goal = self.goals[goalId];
        if (goal.owner != msg.sender) revert NotGoalOwner();
        
        bytes32 actionHash = keccak256(bytes(actionType));
        if (actionHash == keccak256(bytes("FREEZE"))) {
            goal.status = GoalStatus.PAUSED;
        } else if (actionHash == keccak256(bytes("CANCEL"))) {
            goal.status = GoalStatus.CANCELLED;
        }
        
        emit EmergencyAction(goalId, actionType, reason);
    }
    
    function getGoalDetails(
        GoalStorage storage self,
        bytes32 goalId
    ) external view returns (
        string memory name,
        uint256 targetAmount,
        uint256 currentAmount,
        uint256 deadline,
        GoalStatus status,
        uint256 milestoneCount
    ) {
        Goal storage goal = self.goals[goalId];
        return (
            goal.name,
            goal.targetAmount,
            goal.currentAmount,
            goal.deadline,
            goal.status,
            goal.milestoneCount
        );
    }
    
    function getMilestone(
        GoalStorage storage self,
        bytes32 goalId,
        uint256 milestoneIndex
    ) external view returns (
        string memory description,
        uint256 targetAmount,
        uint256 deadline,
        bool isCompleted,
        uint256 completedAt
    ) {
        Milestone storage milestone = self.goals[goalId].milestones[milestoneIndex];
        return (
            milestone.description,
            milestone.targetAmount,
            milestone.deadline,
            milestone.isCompleted,
            milestone.completedAt
        );
    }
    
    function getContributionHistory(
        GoalStorage storage self,
        bytes32 goalId,
        address contributor
    ) external view returns (uint256[] memory) {
        return self.goals[goalId].contributions[contributor];
    }

    function withdraw(
    GoalStorage storage self,
    bytes32 goalId,
    uint256 amount
) external returns (bool) {
    Goal storage goal = self.goals[goalId];
    
    if (goal.owner != msg.sender) revert NotGoalOwner();
    if (goal.status != GoalStatus.ACTIVE && goal.status != GoalStatus.COMPLETED) {
        revert GoalLocked();
    }
    if (amount == 0) revert WithdrawalAmountTooLow();
    if (amount > goal.currentAmount) revert InsufficientBalance();
    
     
    uint256 penalty = 0;
    if (goal.status == GoalStatus.ACTIVE) {
         
        penalty = (amount * 500) / 10000; // 500 basis points = 5%
    }
    
    // Calculate net withdrawal amount
    uint256 netAmount = amount - penalty;
    goal.currentAmount -= amount;
    goal.withdrawals[msg.sender].push(netAmount);
    
    emit WithdrawalProcessed(
        goalId,
        msg.sender,
        netAmount,
        penalty,
        block.timestamp
    );
    
    return true;
}
}