// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./BlockBudget.sol";

contract BlockBudgetFactory {
    mapping(address => address) public userBudgets;
    address[] public allBudgets;

    event BlockBudgetDeployed(address indexed owner, address blockBudget, uint256 deploymentTime);
    event BlockBudgetRemoved(address indexed owner, address blockBudget, uint256 removalTime);

    error BudgetAlreadyExists();
    error BudgetDoesNotExist();
    error InvalidAddress();

    function createBlockBudget() external returns (
        address newBudget) {
        if (userBudgets[msg.sender] != address(0)) revert BudgetAlreadyExists();
        if (msg.sender == address(0)) revert InvalidAddress();

        BlockBudget blockBudget = new BlockBudget();

        blockBudget.transferOwnership(msg.sender);

        userBudgets[msg.sender] = address(blockBudget);
        allBudgets.push(address(blockBudget));

        emit BlockBudgetDeployed(msg.sender, address(blockBudget), block.timestamp);

        return address(blockBudget) ;
    }

    function getAllBudgets() external view returns (address[] memory) {
        return allBudgets;
    }

    function getUserBudget(address user) external view returns (address) {
        if(user == address(0)) revert InvalidAddress();
        return userBudgets[user];
    }
}