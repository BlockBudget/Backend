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
    
    // function removeBlockBudget() external  {
    //     address budgetAddress = userBudgets[msg.sender];
    //     if(budgetAddress == address(0)) revert BudgetDoesNotExist();
        
    //     delete userBudgets[msg.sender];
        
    //     for(uint i = 0; i < allBudgets.length; i++) {
    //         if(allBudgets[i] == budgetAddress) {
    //             allBudgets[i] = allBudgets[allBudgets.length - 1];
    //             allBudgets.pop();
    //             break;
    //         }
    //     }
        
    //     emit BlockBudgetRemoved(msg.sender, budgetAddress, block.timestamp);
    // }

    function getTotalDeployedBudgets() external view returns (uint256) {
        return allBudgets.length;
    }


    function getUserBudget(address user) external view returns (address) {
        if(user == address(0)) revert InvalidAddress();
        return userBudgets[user];
    }

     
    // function getBudgetsPaginated(uint256 offset, uint256 limit) 
    //     external 
    //     view 
    //     returns (address[] memory addresses) 
    // {
    //     uint256 maxLength = allBudgets.length - offset;
    //     uint256 actualLimit = maxLength < limit ? maxLength : limit;
        
    //     addresses = new address[](actualLimit);
    //     for(uint256 i = 0; i < actualLimit; i++) {
    //         addresses[i] = allBudgets[offset + i];
    //     }
        
    //     return addresses;
    // }

     
    // function hasBudget(address user) external view returns (bool) {
    //     return userBudgets[user] != address(0);
    // }
}