// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title ContributionGroupLib
 * @notice Library for managing group contributions and savings pools
 * @dev Handles creation and management of contribution groups
 */
library ContributionGroupLib {
    /* ========== DATA STRUCTURES ========== */
    
    enum ContributionType { FIXED, FLEXIBLE, TIERED }
    enum PrivacyType { PUBLIC, PRIVATE, INVITE_ONLY }
    enum DistributionMethod { ROUND_ROBIN, NEEDS_BASED, MILESTONE_BASED }
    enum GroupStatus { ACTIVE, PAUSED, DISSOLVED }
    
    struct Member {
        bool isActive;
        uint256 joinDate;
        uint256 totalContributed;
        uint256 lastContributionDate;
        uint256 distributionsReceived;
        bool isAdmin;
        bool isApprover;
    }
    
    struct MultisigProposal {
        address proposer;
        bytes32 proposalHash;
        uint256 value;
        uint256 proposedAt;
        uint256 approvalCount;
        bool executed;
        mapping(address => bool) hasApproved;
    }
    
    struct ContributionGroup {
        string name;
        uint256 createdAt;
        uint256 minContribution;
        uint256 totalBalance;
        uint256 memberCount;
        uint256 distributionFrequency;
        uint256 lateFeeRate;
        uint256 minApprovalsRequired;
        ContributionType contributionType;
        PrivacyType privacyType;
        DistributionMethod distributionMethod;
        GroupStatus status;
        address owner;
        mapping(address => Member) members;
        mapping(address => uint256[]) contributionHistory;
        mapping(uint256 => MultisigProposal) proposals;
        uint256 proposalCount;
        mapping(address => bool) invitedMembers;
    }
    
    struct GroupStorage {
        mapping(bytes32 => ContributionGroup) groups;
        mapping(address => bytes32[]) userGroups;
    }

    /* ========== EVENTS ========== */
    
    event GroupCreated(
        bytes32 indexed groupId,
        string name,
        address indexed owner,
        ContributionType contributionType,
        DistributionMethod distributionMethod
    );
    
    event MembershipChanged(
        bytes32 indexed groupId,
        address indexed member,
        string action,
        uint256 timestamp
    );
    
    event ContributionReceived(
        bytes32 indexed groupId,
        address indexed contributor,
        uint256 amount,
        uint256 timestamp
    );
    
    event DistributionProcessed(
        bytes32 indexed groupId,
        address indexed recipient,
        uint256 amount,
        string distributionType
    );
    
    event RulesModified(
        bytes32 indexed groupId,
        string modification,
        uint256 timestamp
    );
    
    event EmergencyActionTriggered(
        bytes32 indexed groupId,
        string actionType,
        string reason
    );
    
    event MultisigProposalCreated(
        bytes32 indexed groupId,
        uint256 indexed proposalId,
        address proposer,
        uint256 value
    );
    
    event MultisigApprovalChanged(
        bytes32 indexed groupId,
        uint256 indexed proposalId,
        address approver,
        bool approved
    );

    /* ========== GROUP CREATION ========== */
    
    function createGroup(
        GroupStorage storage self,
        string memory name,
        ContributionType contributionType,
        PrivacyType privacyType,
        DistributionMethod distributionMethod,
        uint256 minContribution,
        uint256 distributionFrequency,
        uint256 lateFeeRate,
        uint256 minApprovalsRequired
    ) external returns (bytes32) {
        bytes32 groupId = keccak256(
            abi.encodePacked(
                name,
                block.timestamp,
                msg.sender
            )
        );
        
        ContributionGroup storage newGroup = self.groups[groupId];
        newGroup.name = name;
        newGroup.createdAt = block.timestamp;
        newGroup.contributionType = contributionType;
        newGroup.privacyType = privacyType;
        newGroup.distributionMethod = distributionMethod;
        newGroup.minContribution = minContribution;
        newGroup.distributionFrequency = distributionFrequency;
        newGroup.lateFeeRate = lateFeeRate;
        newGroup.minApprovalsRequired = minApprovalsRequired;
        newGroup.owner = msg.sender;
        newGroup.status = GroupStatus.ACTIVE;
        
        // Add owner as first member and admin
        Member storage ownerMember = newGroup.members[msg.sender];
        ownerMember.isActive = true;
        ownerMember.joinDate = block.timestamp;
        ownerMember.isAdmin = true;
        ownerMember.isApprover = true;
        newGroup.memberCount = 1;
        
        self.userGroups[msg.sender].push(groupId);
        
        emit GroupCreated(
            groupId,
            name,
            msg.sender,
            contributionType,
            distributionMethod
        );
        
        return groupId;
    }

    /* ========== MEMBERSHIP MANAGEMENT ========== */
    
    function joinGroup(
        GroupStorage storage self,
        bytes32 groupId
    ) external returns (bool) {
        ContributionGroup storage group = self.groups[groupId];
        require(group.status == GroupStatus.ACTIVE, "Group not active");
        require(!group.members[msg.sender].isActive, "Already a member");
        
        if (group.privacyType == PrivacyType.PRIVATE) {
            require(group.invitedMembers[msg.sender], "Not invited");
        }
        
        Member storage newMember = group.members[msg.sender];
        newMember.isActive = true;
        newMember.joinDate = block.timestamp;
        group.memberCount++;
        
        self.userGroups[msg.sender].push(groupId);
        
        emit MembershipChanged(
            groupId,
            msg.sender,
            "JOINED",
            block.timestamp
        );
        
        return true;
    }
    
    function leaveGroup(
        GroupStorage storage self,
        bytes32 groupId
    ) external returns (uint256) {
        ContributionGroup storage group = self.groups[groupId];
        Member storage member = group.members[msg.sender];
        require(member.isActive, "Not a member");
        
        uint256 refundAmount = _calculateRefund(group, member);
        member.isActive = false;
        group.memberCount--;
        
        emit MembershipChanged(
            groupId,
            msg.sender,
            "LEFT",
            block.timestamp
        );
        
        return refundAmount;
    }

    /* ========== CONTRIBUTION OPERATIONS ========== */
    
    function makeContribution(
        GroupStorage storage self,
        bytes32 groupId,
        uint256 amount
    ) external returns (bool) {
        ContributionGroup storage group = self.groups[groupId];
        Member storage member = group.members[msg.sender];
        require(member.isActive, "Not a member");
        require(amount >= group.minContribution, "Below minimum");
        
        member.totalContributed += amount;
        member.lastContributionDate = block.timestamp;
        group.totalBalance += amount;
        group.contributionHistory[msg.sender].push(amount);
        
        emit ContributionReceived(
            groupId,
            msg.sender,
            amount,
            block.timestamp
        );
        
        return true;
    }
    
    function handleLateFees(
        GroupStorage storage self,
        bytes32 groupId,
        address memberAddress
    ) external returns (uint256) {
        ContributionGroup storage group = self.groups[groupId];
        Member storage member = group.members[memberAddress];
        require(member.isActive, "Not a member");
        
        uint256 timeSinceLastContribution = block.timestamp - member.lastContributionDate;
        if (timeSinceLastContribution > group.distributionFrequency) {
            uint256 penalty = (group.minContribution * group.lateFeeRate) / 10000;
            member.totalContributed -= penalty;
            return penalty;
        }
        return 0;
    }

    /* ========== DISTRIBUTION MANAGEMENT ========== */
    
    function processDistribution(
        GroupStorage storage self,
        bytes32 groupId,
        address recipient,
        uint256 amount,
        string memory distributionType
    ) external returns (bool) {
        ContributionGroup storage group = self.groups[groupId];
        Member storage member = group.members[recipient];
        require(member.isActive, "Not a member");
        require(amount <= group.totalBalance, "Insufficient funds");
        
        group.totalBalance -= amount;
        member.distributionsReceived += amount;
        
        emit DistributionProcessed(
            groupId,
            recipient,
            amount,
            distributionType
        );
        
        return true;
    }
    
    function determineNextRoundRobinRecipient(
        GroupStorage storage self,
        bytes32 groupId
    ) external view returns (address) {
        ContributionGroup storage group = self.groups[groupId];
        require(group.distributionMethod == DistributionMethod.ROUND_ROBIN, "Invalid method");
        
        address nextRecipient;
        uint256 lowestDistributions = type(uint256).max;
        
        // Simple implementation - find member with least distributions
        for (uint256 i = 0; i < self.userGroups[group.owner].length; i++) {
            address member = address(uint160(uint256(self.userGroups[group.owner][i])));
            if (group.members[member].isActive &&
                group.members[member].distributionsReceived < lowestDistributions) {
                lowestDistributions = group.members[member].distributionsReceived;
                nextRecipient = member;
            }
        }
        
        return nextRecipient;
    }

    /* ========== MULTISIG FUNCTIONALITY ========== */
    
    function proposeTransaction(
        GroupStorage storage self,
        bytes32 groupId,
        bytes32 proposalHash,
        uint256 value
    ) external returns (uint256) {
        ContributionGroup storage group = self.groups[groupId];
        require(group.members[msg.sender].isApprover, "Not an approver");
        
        uint256 proposalId = group.proposalCount++;
        MultisigProposal storage proposal = group.proposals[proposalId];
        proposal.proposer = msg.sender;
        proposal.proposalHash = proposalHash;
        proposal.value = value;
        proposal.proposedAt = block.timestamp;
        proposal.hasApproved[msg.sender] = true;
        proposal.approvalCount = 1;
        
        emit MultisigProposalCreated(
            groupId,
            proposalId,
            msg.sender,
            value
        );
        
        return proposalId;
    }
    
    function approveTransaction(
        GroupStorage storage self,
        bytes32 groupId,
        uint256 proposalId
    ) external returns (bool) {
        ContributionGroup storage group = self.groups[groupId];
        MultisigProposal storage proposal = group.proposals[proposalId];
        require(group.members[msg.sender].isApprover, "Not an approver");
        require(!proposal.hasApproved[msg.sender], "Already approved");
        require(!proposal.executed, "Already executed");
        
        proposal.hasApproved[msg.sender] = true;
        proposal.approvalCount++;
        
        emit MultisigApprovalChanged(
            groupId,
            proposalId,
            msg.sender,
            true
        );
        
        if (proposal.approvalCount >= group.minApprovalsRequired) {
            proposal.executed = true;
            return true;
        }
        return false;
    }

    /* ========== ADMINISTRATIVE FUNCTIONS ========== */
    
    function modifyGroupRules(
        GroupStorage storage self,
        bytes32 groupId,
        uint256 newMinContribution,
        uint256 newDistributionFrequency,
        uint256 newLateFeeRate
    ) external {
        ContributionGroup storage group = self.groups[groupId];
        require(msg.sender == group.owner, "Not owner");
        
        if (newMinContribution > 0) group.minContribution = newMinContribution;
        if (newDistributionFrequency > 0) group.distributionFrequency = newDistributionFrequency;
        if (newLateFeeRate > 0) group.lateFeeRate = newLateFeeRate;
        
        emit RulesModified(
            groupId,
            "PARAMETERS_UPDATED",
            block.timestamp
        );
    }
    
    function triggerEmergencyAction(
        GroupStorage storage self,
        bytes32 groupId,
        string memory actionType,
        string memory reason
    ) external {
        ContributionGroup storage group = self.groups[groupId];
        require(msg.sender == group.owner, "Not owner");
        
        if (keccak256(bytes(actionType)) == keccak256(bytes("PAUSE"))) {
            group.status = GroupStatus.PAUSED;
        } else if (keccak256(bytes(actionType)) == keccak256(bytes("DISSOLVE"))) {
            group.status = GroupStatus.DISSOLVED;
        }
        
        emit EmergencyActionTriggered(groupId, actionType, reason);
    }

    /* ========== VIEW FUNCTIONS ========== */
    
    function getGroupDetails(
        GroupStorage storage self,
        bytes32 groupId
    ) external view returns (
        string memory name,
        uint256 totalBalance,
        uint256 memberCount,
        ContributionType contributionType,
        DistributionMethod distributionMethod,
        GroupStatus status
    ) {
        ContributionGroup storage group = self.groups[groupId];
        return (
            group.name,
            group.totalBalance,
            group.memberCount,
            group.contributionType,
            group.distributionMethod,
            group.status
        );
    }
    
    function getMemberDetails(
        GroupStorage storage self,
        bytes32 groupId,
        address memberAddress
    ) external view returns (
        bool isActive,
        uint256 joinDate,
        uint256 totalContributed,
        uint256 distributionsReceived,
        bool isAdmin,
        bool isApprover
    ) {
        Member storage member = self.groups[groupId].members[memberAddress];
        return (
            member.isActive,
            member.joinDate,
            member.totalContributed,
            member.distributionsReceived,
            member.isAdmin,
            member.isApprover
        );
    }
    
    function getContributionHistory(
        GroupStorage storage self,
        bytes32 groupId,
        address memberAddress
    ) external view returns (uint256[] memory) {
        return self.groups[groupId].contributionHistory[memberAddress];
    }

    /* ========== INTERNAL FUNCTIONS ========== */
    
    function _calculateRefund(
        ContributionGroup storage group,
        Member storage member
    ) internal view returns (uint256) {
        // If group is dissolved, return full contribution
        if (group.status == GroupStatus.DISSOLVED) {
            return member.totalContributed;
        }
        
        // Calculate time spent in group
        uint256 membershipDuration = block.timestamp - member.joinDate;
        
        // If member has received distributions, deduct them from refund
        uint256 baseRefund = member.totalContributed;
        if (member.distributionsReceived > 0) {
            baseRefund = baseRefund > member.distributionsReceived ? 
                        baseRefund - member.distributionsReceived : 0;
        }
        
        // Apply early withdrawal penalty if applicable
        // (if leaving before one distribution cycle)
        if (membershipDuration < group.distributionFrequency) {
            uint256 penalty = (baseRefund * group.lateFeeRate) / 10000;
            baseRefund = baseRefund > penalty ? baseRefund - penalty : 0;
        }
        
        // Ensure refund doesn't exceed group's total balance
        return baseRefund > group.totalBalance ? group.totalBalance : baseRefund;
    }
}