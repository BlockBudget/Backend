// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title CrowdfundingLib
 * @notice Library for managing crowdfunding campaigns
 * @dev Handles creation and management of crowdfunding campaigns
 */
library ContributionLib {
    
    struct Campaign {
        string name;
        address owner;
        uint256 targetAmount;
        uint256 deadline;
        uint256 totalContributed;
        uint256 contributorCount;
        bool isActive;
        mapping(address => uint256) contributions;
    }
    
    struct CampaignStorage {
        mapping(bytes32 => Campaign) campaigns;
        mapping(address => bytes32[]) userCampaigns;
    }
    
    event CampaignCreated(
        bytes32 indexed campaignId,
        string name,
        address indexed owner,
        uint256 targetAmount,
        uint256 deadline
    );
    
    event ContributionMade(
        bytes32 indexed campaignId,
        address indexed contributor,
        uint256 amount
    );
    
    event CampaignEnded(
        bytes32 indexed campaignId,
        address indexed owner,
        uint256 totalContributed,
        bool goalMet
    );
    
    function createCampaign(
        CampaignStorage storage self,
        string memory name,
        uint256 targetAmount,
        uint256 duration
    ) external returns (bytes32) {
        require(targetAmount > 0, "Target amount must be positive");
        require(duration > 0, "Duration must be positive");
        
        bytes32 campaignId = keccak256(
            abi.encodePacked(name, block.timestamp, msg.sender)
        );
        
        Campaign storage newCampaign = self.campaigns[campaignId];
        newCampaign.name = name;
        newCampaign.owner = msg.sender;
        newCampaign.targetAmount = targetAmount;
        newCampaign.deadline = block.timestamp + duration;
        newCampaign.isActive = true;
        
        self.userCampaigns[msg.sender].push(campaignId);
        
        emit CampaignCreated(campaignId, name, msg.sender, targetAmount, newCampaign.deadline);
        
        return campaignId;
    }
    
    function contribute(
        CampaignStorage storage self,
        bytes32 campaignId
    ) external payable returns (bool) {
        Campaign storage campaign = self.campaigns[campaignId];
        require(campaign.isActive, "Campaign not active");
        require(block.timestamp < campaign.deadline, "Campaign has ended");
        require(msg.value > 0, "Contribution must be positive");
        
        if (campaign.contributions[msg.sender] == 0) {
            campaign.contributorCount++;
        }
        
        campaign.contributions[msg.sender] += msg.value;
        campaign.totalContributed += msg.value;
        
        emit ContributionMade(campaignId, msg.sender, msg.value);
        
        return true;
    }
    
    function endCampaign(
        CampaignStorage storage self,
        bytes32 campaignId
    ) external returns (bool) {
        Campaign storage campaign = self.campaigns[campaignId];
        require(msg.sender == campaign.owner, "Only owner can end the campaign");
        require(block.timestamp >= campaign.deadline, "Campaign still active");
        require(campaign.isActive, "Campaign already ended");
        
        campaign.isActive = false;
        
        bool goalMet = campaign.totalContributed >= campaign.targetAmount;
        
        if (goalMet) {
            payable(campaign.owner).transfer(campaign.totalContributed);
        }
        
        emit CampaignEnded(campaignId, campaign.owner, campaign.totalContributed, goalMet);
        
        return goalMet;
    }
    
    function getCampaignDetails(
        CampaignStorage storage self,
        bytes32 campaignId
    ) external view returns (
        string memory name,
        address owner,
        uint256 targetAmount,
        uint256 deadline,
        uint256 totalContributed,
        uint256 contributorCount,
        bool isActive
    ) {
        Campaign storage campaign = self.campaigns[campaignId];
        return (
            campaign.name,
            campaign.owner,
            campaign.targetAmount,
            campaign.deadline,
            campaign.totalContributed,
            campaign.contributorCount,
            campaign.isActive
        );
    }
    
    function getContribution(
        CampaignStorage storage self,
        bytes32 campaignId,
        address contributor
    ) external view returns (uint256) {
        return self.campaigns[campaignId].contributions[contributor];
    }
}
