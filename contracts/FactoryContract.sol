// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./BlockBudget.sol";

/**
 * @title BlockBudgetFactory
 * @notice Factory contract to deploy instances of the BlockBudget contract
 */
contract BlockBudgetFactory {
    // Mapping to store deployed BlockBudget instances by the user who deployed them
    mapping(address => address) public userBudgets;
    
    // Array to keep track of all deployed BlockBudget contracts
    address[] public allBudgets;

    // Event emitted when a new BlockBudget contract is deployed
    event BlockBudgetDeployed(address indexed owner, address blockBudget);

    /**
     * @dev Deploys a new BlockBudget contract and assigns it to the caller
     * @return The address of the newly deployed BlockBudget contract
     */
    function createBlockBudget() external returns (address) {
        require(userBudgets[msg.sender] == address(0), "BlockBudget already exists for this user");

        // Deploy a new BlockBudget instance
        BlockBudget blockBudget = new BlockBudget();

        // Transfer ownership of the BlockBudget instance to the caller
        blockBudget.transferOwnership(msg.sender);

        // Store the address of the deployed BlockBudget contract
        userBudgets[msg.sender] = address(blockBudget);
        allBudgets.push(address(blockBudget));

        // Emit an event for the new deployment
        emit BlockBudgetDeployed(msg.sender, address(blockBudget));

        return address(blockBudget);
    }

    /**
     * @dev Returns the total number of BlockBudget contracts deployed by the factory
     * @return The count of all deployed BlockBudget contracts
     */
    function getTotalDeployedBudgets() external view returns (uint256) {
        return allBudgets.length;
    }

    /**
     * @dev Retrieves the address of the BlockBudget contract deployed by a specific user
     * @param user The address of the user
     * @return The address of the BlockBudget contract deployed by the user
     */
    function getUserBudget(address user) external view returns (address) {
        return userBudgets[user];
    }
}
