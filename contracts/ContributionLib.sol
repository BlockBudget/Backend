// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title ContributionLib
 * @notice Enhanced library for managing public and private crowdfunding campaigns
 * @dev Handles creation and management of crowdfunding campaigns with whitelist support
 */
library ContributionLib {
    
    struct Campaign {
        string name;
        string description;
        address owner;
        uint256 targetAmount;
        uint256 deadline;
        uint256 totalContributed;
        uint256 contributorCount;
        bool isActive;
        bool isPrivate;
        mapping(address => bool) whitelist;
        mapping(address => uint256) contributions;
    }
    
    struct CampaignStorage {
        mapping(bytes32 => Campaign) campaigns;
        mapping(address => bytes32[]) userCampaigns;
    }
    
    event CampaignCreated(
        bytes32 indexed campaignId,
        string name,
        string description,
        address indexed owner,
        uint256 targetAmount,
        uint256 deadline,
        bool isPrivate
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
    
    event AddressWhitelisted(
        bytes32 indexed campaignId,
        address indexed whitelistedAddress
    );
    
    event FundsWithdrawn(
        bytes32 indexed campaignId,
        address indexed contributor,
        uint256 amount
    );
    
    function createCampaign(
        CampaignStorage storage self,
        string memory name,
        string memory description,
        uint256 targetAmount,
        uint256 duration,
        bool isPrivate
    ) external returns (bytes32) {
        require(targetAmount > 0, "Target amount must be positive");
        require(duration > 0, "Duration must be positive");
        
        bytes32 campaignId = keccak256(
            abi.encodePacked(name, block.timestamp, msg.sender)
        );
        
        Campaign storage newCampaign = self.campaigns[campaignId];
        newCampaign.name = name;
        newCampaign.description = description;
        newCampaign.owner = msg.sender;
        newCampaign.targetAmount = targetAmount;
        newCampaign.deadline = block.timestamp + duration;
        newCampaign.isActive = true;
        newCampaign.isPrivate = isPrivate;
        
        self.userCampaigns[msg.sender].push(campaignId);
        
        emit CampaignCreated(
            campaignId,
            name,
            description,
            msg.sender,
            targetAmount,
            newCampaign.deadline,
            isPrivate
        );
        
        return campaignId;
    }
    
    function whitelistAddresses(
        CampaignStorage storage self,
        bytes32 campaignId,
        address[] memory addresses
    ) external {
        Campaign storage campaign = self.campaigns[campaignId];
        require(msg.sender == campaign.owner, "Only owner can whitelist addresses");
        require(campaign.isPrivate, "Campaign is not private");
        require(campaign.isActive, "Campaign not active");
        
        for (uint256 i = 0; i < addresses.length; i++) {
            campaign.whitelist[addresses[i]] = true;
            emit AddressWhitelisted(campaignId, addresses[i]);
        }
    }
    
    function contribute(
        CampaignStorage storage self,
        bytes32 campaignId
    ) external returns (bool) {
        Campaign storage campaign = self.campaigns[campaignId];
        require(campaign.isActive, "Campaign not active");
        require(block.timestamp < campaign.deadline, "Campaign has ended");
        require(msg.value > 0, "Contribution must be positive");
        
        if (campaign.isPrivate) {
            require(campaign.whitelist[msg.sender], "Address not whitelisted");
        }
        
        if (campaign.contributions[msg.sender] == 0) {
            campaign.contributorCount++;
        }
        
        campaign.contributions[msg.sender] += msg.value;
        campaign.totalContributed += msg.value;
        
        emit ContributionMade(campaignId, msg.sender, msg.value);
        
        return true;
    }
    
    function withdrawContribution(
        CampaignStorage storage self,
        bytes32 campaignId
    ) external returns (bool) {
        Campaign storage campaign = self.campaigns[campaignId];
        require(!campaign.isActive || block.timestamp >= campaign.deadline, "Campaign still active");
        require(campaign.totalContributed < campaign.targetAmount, "Target amount met");
        
        uint256 contributionAmount = campaign.contributions[msg.sender];
        require(contributionAmount > 0, "No contribution to withdraw");
        
        campaign.contributions[msg.sender] = 0;
        campaign.totalContributed -= contributionAmount;
        
        if (contributionAmount > 0) {
            campaign.contributorCount--;
        }
        
        payable(msg.sender).transfer(contributionAmount);
        
        emit FundsWithdrawn(campaignId, msg.sender, contributionAmount);
        
        return true;
    }
    
    function endCampaign(
        CampaignStorage storage self,
        bytes32 campaignId
    ) external returns (bool) {
        Campaign storage campaign = self.campaigns[campaignId];
        require(msg.sender == campaign.owner, "Only owner can end campaign");
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
        string memory description,
        address owner,
        uint256 targetAmount,
        uint256 deadline,
        uint256 totalContributed,
        uint256 contributorCount,
        bool isActive,
        bool isPrivate
    ) {
        Campaign storage campaign = self.campaigns[campaignId];
        return (
            campaign.name,
            campaign.description,
            campaign.owner,
            campaign.targetAmount,
            campaign.deadline,
            campaign.totalContributed,
            campaign.contributorCount,
            campaign.isActive,
            campaign.isPrivate
        );
    }
    
    function getContribution(
        CampaignStorage storage self,
        bytes32 campaignId,
        address contributor
    ) external view returns (uint256) {
        return self.campaigns[campaignId].contributions[contributor];
    }
    
    function isWhitelisted(
        CampaignStorage storage self,
        bytes32 campaignId,
        address contributor
    ) external view returns (bool) {
        Campaign storage campaign = self.campaigns[campaignId];
        return !campaign.isPrivate || campaign.whitelist[contributor];
    }
}