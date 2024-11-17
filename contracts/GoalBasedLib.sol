// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library GoalBasedLib {

    enum GoalStatus { Activited, Complete, Cancelled}
    enum GoalType {SelfContribution, GroupContribution}

    struct Milestone {
        string description;
        uint256 targetAmount;
        uint256 deadline;
        bool isCompleted;
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
        bool isFlexible;
        bool autoContribute;
        address owner;
        uint256 milestoneCount;
        uint256[] savingDates;
        mapping(uint256 => Milestone) milestones;
        mapping(address => uint256[]) contributions;
        mapping(address => uint256[]) withdrawals;
    }

    struct GoalStorage {
        mapping(bytes32 => Goal) goals;
        mapping(address => bytes32[]) userGoals;
        uint256 totalGoals;
    }

    event GoalCreated(bytes32 indexed goalId, address indexed owner, string name, uint256 targetAmount, uint256 deadline);
    event ContributionMade(bytes32 indexed goalId, address indexed contributor, uint256 amount);
    event WithdrawalProcessed(bytes32 indexed goalId, address indexed withdrawer, uint256 amount, uint256 penalty);
    event GoalCancelled(bytes32 indexed goalId, uint256 remainingFunds, address indexed owner);

    /**
     * @notice Cancel a goal and refund remaining funds to the owner.
     * @dev Marks the goal as CANCELLED and prevents further operations.
     * @param self The storage reference to the GoalStorage struct.
     * @param goalId The unique identifier for the goal to cancel.
     */
    function cancelGoal(GoalStorage storage self, bytes32 goalId) external {
        Goal storage goal = self.goals[goalId];
        require(goal.owner == msg.sender, "Not goal owner");
        require(goal.status == GoalStatus.Activited, "Goal not active");

        uint256 remainingFunds = goal.currentAmount;

        goal.status = GoalStatus.CANCELLED;
        goal.currentAmount = 0;

        // Refund remaining funds to the owner (assumes an external call handles this)
        // payable(goal.owner).transfer(remainingFunds);

        emit GoalCancelled(goalId, remainingFunds, goal.owner);
    }

    /**
     * @notice Deduct penalties for withdrawals before the goal deadline.
     * @dev Penalty is calculated based on the `penaltyRate` of the goal.
     * @param self The storage reference to the GoalStorage struct.
     * @param goalId The unique identifier for the goal.
     * @param withdrawAmount The amount to be withdrawn.
     * @return uint256 The penalty amount deducted.
     */
    function calculatePenalty(GoalStorage storage self, bytes32 goalId, uint256 withdrawAmount) external view returns (uint256) {
        Goal storage goal = self.goals[goalId];
        require(goal.status == GoalStatus.Activited, "Goal not active");

        uint256 penalty = (withdrawAmount * goal.penaltyRate) / 100;
        return penalty;
    }

    /**
     * @notice Process a batch of contributions to a goal.
     * @param self The storage reference to the GoalStorage struct.
     * @param goalId The unique identifier for the goal.
     * @param contributors Array of contributor addresses.
     * @param amounts Array of contribution amounts corresponding to contributors.
     */
    function batchContribute(GoalStorage storage self, bytes32 goalId,address[] memory contributors, uint256[] memory amounts) external {
        require(contributors.length == amounts.length, "Mismatched arrays");
        Goal storage goal = self.goals[goalId];
        require(goal.status == GoalStatus.Activited, "Goal not active");

        for (uint256 i = 0; i < contributors.length; i++) {
            address contributor = contributors[i];
            uint256 amount = amounts[i];
            require(amount >= goal.minContributionAmount, "Amount too low");

            goal.currentAmount += amount;
            goal.contributions[contributor].push(amount);

            emit ContributionMade(goalId, contributor, amount);
        }
    }

    /**
     * @notice Process a batch of withdrawals from a goal.
     * @param self The storage reference to the GoalStorage struct.
     * @param goalId The unique identifier for the goal.
     * @param withdrawers Array of withdrawer addresses.
     * @param amounts Array of withdrawal amounts corresponding to withdrawers.
     */
    function batchWithdraw( GoalStorage storage self, bytes32 goalId, address[] memory withdrawers, uint256[] memory amounts) external {
    require(withdrawers.length == amounts.length, "Mismatched arrays");
    Goal storage goal = self.goals[goalId];
    require(goal.status == GoalStatus.Activited, "Goal not Activited");

    for (uint256 i = 0; i < withdrawers.length; i++) {
        address withdrawer = withdrawers[i];
        uint256 amount = amounts[i];
        require(amount <= goal.currentAmount, "Insufficient funds");

        uint256 penalty = (amount * goal.penaltyRate) / 100;

        // Deduct penalty and reduce goal's current amount
        goal.currentAmount -= amount;

        // Record the withdrawal
        goal.withdrawals[withdrawer].push(amount);

        // Transfer net amount to the withdrawer (assume external transfer function)
        // payable(withdrawer).transfer(amount - penalty);

        emit WithdrawalProcessed(goalId, withdrawer, amount, penalty);
    }
}


    /**
     * @notice Logs all transactions for a specific goal.
     * @dev Provides visibility into contributions and withdrawals.
     * @param self The storage reference to the GoalStorage struct.
     * @param goalId The unique identifier for the goal.
     * @return contributions Array of all contributions for the goal.
     * @return withdrawals Array of all withdrawals for the goal.
     */
    function getTransactionLog(GoalStorage storage self, bytes32 goalId) external view returns (uint256[] memory contributions, uint256[] memory withdrawals) {
        Goal storage goal = self.goals[goalId];
        contributions = goal.contributions[msg.sender];
        withdrawals = goal.withdrawals[msg.sender];
    }
}

