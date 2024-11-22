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
        bool locked;
        mapping(address => bool) whitelist;
        mapping(address => uint256) contributions;
    }
    
    struct CampaignStorage {
        mapping(bytes32 => Campaign) campaigns;
        mapping(address => bytes32[]) userCampaigns;
    }

    uint256 private constant MAX_DURATION = 365 days;
    uint256 private constant MIN_TARGET_AMOUNT = 0.01 ether;
    uint256 private constant MAX_TARGET_AMOUNT = 10000 ether;
    uint256 private constant MAX_BATCH_SIZE = 200;
    
    error InvalidAmount();
    error InvalidDuration();
    error CampaignNotFound();
    error Unauthorized();
    error CampaignNotActive();
    error CampaignEnded();
    error DeadlineNotReached();
    error NotWhitelisted();
    error ReentrantCall();
    error NoContribution();
    error BatchTooLarge();
    error TransferFailed();
    
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
        uint256 amount,
        uint256 totalRaised
    );
    
    event AddressWhitelisted(
        bytes32 indexed campaignId,
        address indexed whitelistedAddress
    );
    
    event FundsWithdrawn(
        bytes32 indexed campaignId,
        address indexed contributor,
        uint256 amount,
        uint256 remainingBalance
    );

    event ContributionRefunded(
        bytes32 indexed campaignId,
        address indexed contributor,
        uint256 amount
    );
    
    modifier campaignExists(CampaignStorage storage self, bytes32 campaignId) {
        if(self.campaigns[campaignId].owner == address(0)) revert CampaignNotFound();
        _;
    }

    modifier nonReentrant(Campaign storage campaign) {
        if(campaign.locked) revert ReentrantCall();
        campaign.locked = true;
        _;
        campaign.locked = false;
    }

    modifier onlyCampaignOwner(Campaign storage campaign) {
        if(msg.sender != campaign.owner) revert Unauthorized();
        _;
    }
    
    function createCampaign(
        CampaignStorage storage self,
        string memory name,
        string memory description,
        uint256 targetAmount,
        uint256 duration,
        bool isPrivate
    ) external returns (bytes32) {
        if(targetAmount < MIN_TARGET_AMOUNT || targetAmount > MAX_TARGET_AMOUNT) revert InvalidAmount();
        if(duration == 0 || duration > MAX_DURATION / 1 days) revert InvalidDuration();
        
        bytes32 campaignId = keccak256(
            abi.encodePacked(name, block.timestamp, msg.sender)
        );
        
        Campaign storage newCampaign = self.campaigns[campaignId];
        newCampaign.name = name;
        newCampaign.description = description;
        newCampaign.owner = msg.sender;
        newCampaign.targetAmount = targetAmount;
        newCampaign.deadline = block.timestamp + (duration * 1 days);
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
        address[] calldata addresses
    ) external 
        campaignExists(self, campaignId)
        onlyCampaignOwner(self.campaigns[campaignId]) 
    {
        Campaign storage campaign = self.campaigns[campaignId];
        if(!campaign.isPrivate) revert Unauthorized();
        if(!campaign.isActive) revert CampaignNotActive();
        if(addresses.length > MAX_BATCH_SIZE) revert BatchTooLarge();
        
        for (uint256 i = 0; i < addresses.length; i++) {
            address addr = addresses[i];
            if(addr != address(0)) {
                campaign.whitelist[addr] = true;
                emit AddressWhitelisted(campaignId, addr);
            }
        }
    }
    
    function contribute(
        CampaignStorage storage self,
        bytes32 campaignId
    ) external 
        campaignExists(self, campaignId)
        returns (bool) 
    {
        Campaign storage campaign = self.campaigns[campaignId];
        if(!campaign.isActive) revert CampaignNotActive();
        if(block.timestamp >= campaign.deadline) revert CampaignEnded();
        if(msg.value == 0) revert InvalidAmount();
        
        if(campaign.isPrivate && !campaign.whitelist[msg.sender]) revert NotWhitelisted();
        
        if(campaign.contributions[msg.sender] == 0) {
            campaign.contributorCount++;
        }
        
        campaign.contributions[msg.sender] += msg.value;
        campaign.totalContributed += msg.value;
        
        emit ContributionMade(
            campaignId,
            msg.sender,
            msg.value,
            campaign.totalContributed
        );
        
        return true;
    }
    
    function withdrawContribution(
        CampaignStorage storage self,
        bytes32 campaignId
    ) external 
        campaignExists(self, campaignId)
        nonReentrant(self.campaigns[campaignId])
        returns (bool) 
    {
        Campaign storage campaign = self.campaigns[campaignId];
        if(campaign.isActive && block.timestamp < campaign.deadline) revert CampaignNotActive();
        if(campaign.totalContributed >= campaign.targetAmount) revert Unauthorized();
        
        uint256 amount = campaign.contributions[msg.sender];
        if(amount == 0) revert NoContribution();
        
        campaign.contributions[msg.sender] = 0;
        campaign.totalContributed -= amount;
        campaign.contributorCount--;
        
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if(!success) revert TransferFailed();
        
        emit FundsWithdrawn(
            campaignId,
            msg.sender,
            amount,
            campaign.totalContributed
        );
        
        return true;
    }

    function withdrawContributions(
        CampaignStorage storage self,
        bytes32 campaignId
    ) external 
        campaignExists(self, campaignId)
        onlyCampaignOwner(self.campaigns[campaignId])
        nonReentrant(self.campaigns[campaignId]) 
        returns (bool) 
    {
        Campaign storage campaign = self.campaigns[campaignId];
        if (!campaign.isActive) revert CampaignNotActive();
        if (campaign.totalContributed < campaign.targetAmount) revert Unauthorized(); // Target not met
        
        // Mark the campaign as inactive after withdrawal
        campaign.isActive = false;

        uint256 amount = campaign.totalContributed;
        campaign.totalContributed = 0; // Reset the total contributions

        (bool success, ) = payable(campaign.owner).call{value: amount}("");
        if (!success) revert TransferFailed();

        emit FundsWithdrawn(campaignId, msg.sender, amount, 0);

        return true;
    }

    
    function endCampaign(
        CampaignStorage storage self,
        bytes32 campaignId
    ) external 
        campaignExists(self, campaignId)
        onlyCampaignOwner(self.campaigns[campaignId])
        nonReentrant(self.campaigns[campaignId]) 
        returns (bool) 
    {
        Campaign storage campaign = self.campaigns[campaignId];
        if (!campaign.isActive) revert CampaignNotActive();

        // If the target is reached before the deadline, allow early ending
        if (campaign.totalContributed >= campaign.targetAmount) {
            campaign.isActive = false;

            uint256 amount = campaign.totalContributed;
            campaign.totalContributed = 0;

            (bool success, ) = payable(campaign.owner).call{value: amount}("");
            if (!success) revert TransferFailed();

            emit FundsWithdrawn(campaignId, campaign.owner, amount, 0);

            return true;
        }

        // If the deadline has passed, end the campaign without a successful target
        if (block.timestamp >= campaign.deadline) {
            campaign.isActive = false;
            return false;
        }

        revert DeadlineNotReached();
    }


    function refundContribution(
        CampaignStorage storage self,
        bytes32 campaignId,
        address contributor
    ) external 
        campaignExists(self, campaignId)
        onlyCampaignOwner(self.campaigns[campaignId])
        nonReentrant(self.campaigns[campaignId])
        returns (bool) 
    {
        Campaign storage campaign = self.campaigns[campaignId];
        if(!campaign.isActive) revert CampaignNotActive();
        
        uint256 amount = campaign.contributions[contributor];
        if(amount == 0) revert NoContribution();
        
        campaign.contributions[contributor] = 0;
        campaign.totalContributed -= amount;
        campaign.contributorCount--;
        
        (bool success, ) = payable(contributor).call{value: amount}("");
        if(!success) revert TransferFailed();
        
        emit ContributionRefunded(campaignId, contributor, amount);
        
        return true;
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

    function getUserCampaigns(
        CampaignStorage storage self,
        address user
    ) external view returns (bytes32[] memory) {
        return self.userCampaigns[user];
    }

    function getTotalContributions(
        CampaignStorage storage self,
        bytes32 campaignId
    ) external view campaignExists(self, campaignId) returns (uint256) {
        return self.campaigns[campaignId].totalContributed;
    }

}