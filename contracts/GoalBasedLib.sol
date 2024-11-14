// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title GoalBasedSavingsLib
 * @notice Library for managing goal-based savings targets and milestones
 * @dev Implements functionality for personal and group savings goals
 */
library GoalBasedSavingsLib {
    
    enum GoalType { PERSONAL, GROUP, CHALLENGE }
    enum GoalStatus { ACTIVE, PAUSED, COMPLETED, CANCELLED }
    enum SavingFrequency { DAILY, WEEKLY, MONTHLY, FLEXIBLE }
    
    struct Milestone {
        string description;
        uint256 targetAmount;
        uint256 deadline;
        bool isCompleted;
        uint256 rewardAmount;
        uint256 completedAt;
    }
    
    struct Goal {
        string name;
        uint256 targetAmount;
        uint256 currentAmount;
        uint256 deadline;
        uint256 createdAt;
        uint256 minContributionAmount;
        uint256 penaltyRate;
        GoalType goalType;
        GoalStatus status;
        SavingFrequency frequency;
        bool isFlexible;
        bool autoContribute;
        address owner;
        uint256 milestoneCount;
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
    
    event GoalCompleted(bytes32 indexed goalId, uint256 timestamp);
    
    event EmergencyAction(
        bytes32 indexed goalId,
        string actionType,
        string reason
    );
    
    function createGoal(
        GoalStorage storage self,
        string memory name,
        uint256 targetAmount,
        uint256 deadline,
        GoalType goalType,
        SavingFrequency frequency,
        uint256 minContributionAmount,
        bool isFlexible,
        bool autoContribute,
        uint256 penaltyRate
    ) external returns (bytes32) {
        require(targetAmount > 0, "Invalid target amount");
        require(deadline > block.timestamp, "Invalid deadline");
        
        bytes32 goalId = keccak256(
            abi.encodePacked(
                name,
                block.timestamp,
                msg.sender
            )
        );
        
        Goal storage newGoal = self.goals[goalId];
        newGoal.name = name;
        newGoal.targetAmount = targetAmount;
        newGoal.deadline = deadline;
        newGoal.createdAt = block.timestamp;
        newGoal.goalType = goalType;
        newGoal.frequency = frequency;
        newGoal.minContributionAmount = minContributionAmount;
        newGoal.isFlexible = isFlexible;
        newGoal.autoContribute = autoContribute;
        newGoal.penaltyRate = penaltyRate;
        newGoal.owner = msg.sender;
        newGoal.status = GoalStatus.ACTIVE;
        
        self.userGoals[msg.sender].push(goalId);
        self.totalGoals++;
        
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
        string memory description,
        uint256 targetAmount,
        uint256 deadline,
        uint256 rewardAmount
    ) external returns (uint256) {
        Goal storage goal = self.goals[goalId];
        require(goal.owner == msg.sender, "Not goal owner");
        require(deadline <= goal.deadline, "Invalid milestone deadline");
        
        uint256 milestoneIndex = goal.milestoneCount++;
        Milestone storage milestone = goal.milestones[milestoneIndex];
        
        milestone.description = description;
        milestone.targetAmount = targetAmount;
        milestone.deadline = deadline;
        milestone.rewardAmount = rewardAmount;
        
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
        
        percentageComplete = (goal.currentAmount * 100) / goal.targetAmount;
        remaining = goal.targetAmount - goal.currentAmount;
        timeLeft = goal.deadline > block.timestamp ? 
                  goal.deadline - block.timestamp : 0;
    }
    
    function trackSavingRate(
        GoalStorage storage self,
        bytes32 goalId
    ) external view returns (uint256) {
        Goal storage goal = self.goals[goalId];
        if (block.timestamp <= goal.createdAt) return 0;
        
        return (goal.currentAmount * 1e18) / 
               (block.timestamp - goal.createdAt);
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
        require(goal.owner == msg.sender, "Not goal owner");
        require(goal.status == GoalStatus.ACTIVE, "Goal not active");
        
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
        require(goal.owner == msg.sender, "Not goal owner");
        require(amount <= goal.currentAmount, "Insufficient funds");
        
        uint256 penalty = 0;
        if (!isEmergency && goal.status == GoalStatus.ACTIVE) {
            penalty = (amount * goal.penaltyRate) / 10000;
        }
        
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
    
    function emergencyAction(
        GoalStorage storage self,
        bytes32 goalId,
        string memory actionType,
        string memory reason
    ) external {
        Goal storage goal = self.goals[goalId];
        require(goal.owner == msg.sender, "Not goal owner");
        
        if (keccak256(bytes(actionType)) == keccak256(bytes("FREEZE"))) {
            goal.status = GoalStatus.PAUSED;
        } else if (keccak256(bytes(actionType)) == keccak256(bytes("CANCEL"))) {
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
}