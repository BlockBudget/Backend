// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title TimeLockedSavingsLib
 * @notice Library implementing time-locked savings functionality with interest mechanisms
 */
library TimeLockedLib {
    
    error InvalidOwner();
    error AccountExists();
    error InsufficientBalance();
    error InvalidAmount();
    error AccountNotActive();
    error ReentrantCall();
    error InvalidDuration();
    error TimePeriodTooLong();
    error AmountTooLarge();
    error OverflowError();
    error PenaltyExceedsAmount();
    
    enum AccountType { FIXED_TERM, FLEXIBLE_TERM, LADDER_TERM }
    
    enum InterestType { FIXED, VARIABLE, COMPOUND }
    
    struct Account {
        uint256 balance;
        uint256 lastInterestCalculation;
        uint256 accruedInterest;
        uint256 interestRate;
        uint256 lockEndTime;
        uint256 createdAt;
        AccountType accountType;
        InterestType interestType;
        bool isActive;
    }

    struct AccountStorage {
        mapping(address => Account) accounts;
        mapping(address => uint256[]) deposits;
        mapping(address => uint256[]) withdrawals;
        mapping(address => uint256) totalInterestEarned;
    }
    
    event AccountCreated(
        address indexed owner,
        AccountType accountType,
        InterestType interestType,
        uint256 initialDeposit,
        uint256 lockDuration
    );
    
    event DepositReceived(
        address indexed owner,
        uint256 amount,
        uint256 newBalance
    );
    
    event InterestPaid(
        address indexed owner,
        uint256 amount,
        uint256 timestamp
    );
    
    event WithdrawalProcessed(
        address indexed owner,
        uint256 amount,
        uint256 penalty
    );
    
    event LockModified(
        address indexed owner,
        uint256 newLockEndTime
    );
    
    uint256 private constant SECONDS_PER_YEAR = 365 days;
    uint256 private constant BASE_RATE = 500; // 5% represented as basis points
    uint256 private constant BASIS_POINTS = 10000;
    
    modifier nonReentrant(AccountStorage storage self) {
        if (self.accounts[msg.sender].isActive && 
            self.accounts[msg.sender].lastInterestCalculation >= block.timestamp) {
            revert ReentrantCall();
        }
        _;
    }
    
    modifier validAccount(AccountStorage storage self, address owner) {
        if (!self.accounts[owner].isActive) revert AccountNotActive();
        _;
    }
    
    function createAccount(
        AccountStorage storage self,
        address owner,
        AccountType accountType,
        InterestType interestType,
        uint256 lockDuration,
        uint256 initialDeposit
    ) external nonReentrant(self) returns (bool) {
        if (owner == address(0)) revert InvalidOwner();
        if (initialDeposit == 0) revert InvalidAmount();
        if (self.accounts[owner].isActive) revert AccountExists();
        if (lockDuration == 0) revert InvalidDuration();
        if (lockDuration > 10 * SECONDS_PER_YEAR) revert InvalidDuration();
        
        uint256 interestRate = _calculateInterestRate(accountType, lockDuration);
        
        // Use memory struct before storage for gas optimization
        Account memory newAccount = Account({
            balance: initialDeposit,
            lastInterestCalculation: block.timestamp,
            accruedInterest: 0,
            interestRate: interestRate,
            lockEndTime: block.timestamp + lockDuration,
            createdAt: block.timestamp,
            accountType: accountType,
            interestType: interestType,
            isActive: true
        });
        
        self.accounts[owner] = newAccount;
        self.deposits[owner].push(initialDeposit);
        
        emit AccountCreated(
            owner,
            accountType,
            interestType,
            initialDeposit,
            lockDuration
        );
        
        return true;
    }
    
    function deposit(
        AccountStorage storage self,
        address owner,
        uint256 amount
    ) external nonReentrant(self) validAccount(self, owner) returns (bool) {
        if (amount == 0) revert InvalidAmount();
        
        Account storage account = self.accounts[owner];
        
        // Overflow check
        if (account.balance + amount < account.balance) revert OverflowError();
        if (amount > type(uint256).max - account.balance) revert AmountTooLarge();
        
        account.balance += amount;
        self.deposits[owner].push(amount);
        
        emit DepositReceived(owner, amount, account.balance);
        
        return true;
    }
    
    function calculateInterest(
        AccountStorage storage self,
        address owner
    ) external nonReentrant(self) validAccount(self, owner) returns (uint256) {
        Account storage account = self.accounts[owner];
        
        // Cache storage reads
        uint256 timeElapsed;
        unchecked {
            timeElapsed = block.timestamp - account.lastInterestCalculation;
        }
        uint256 currentBalance = account.balance;
        uint256 currentRate = account.interestRate;
        
        if (timeElapsed > 100 * SECONDS_PER_YEAR) revert TimePeriodTooLong();
        
        uint256 interest;
        
        if (account.interestType == InterestType.COMPOUND) {
            interest = _calculateCompoundInterest(
                currentBalance,
                currentRate,
                timeElapsed
            );
        } else {
            interest = _calculateSimpleInterest(
                currentBalance,
                currentRate,
                timeElapsed
            );
        }
        
        // Overflow check
        if (account.accruedInterest + interest < account.accruedInterest) revert OverflowError();
        
        account.accruedInterest += interest;
        account.lastInterestCalculation = block.timestamp;
        self.totalInterestEarned[owner] += interest;
        
        emit InterestPaid(owner, interest, block.timestamp);
        
        return interest;
    }
    
    function withdraw(
        AccountStorage storage self,
        address owner,
        uint256 amount
    ) external nonReentrant(self) validAccount(self, owner) returns (bool) {
        if (amount == 0) revert InvalidAmount();
        
        Account storage account = self.accounts[owner];
        uint256 currentBalance = account.balance;
        uint256 currentInterest = account.accruedInterest;
        
        if (amount > currentBalance + currentInterest) revert InsufficientBalance();
        
        uint256 penalty = 0;
        if (block.timestamp < account.lockEndTime) {
            penalty = _calculateWithdrawalPenalty(amount, account);
        }
        
        if (amount < penalty) revert PenaltyExceedsAmount();
        
        uint256 netWithdrawal;
        unchecked {
            netWithdrawal = amount - penalty;
            account.balance = currentBalance - amount;
        }
        
        self.withdrawals[owner].push(netWithdrawal);
        
        emit WithdrawalProcessed(owner, netWithdrawal, penalty);
        
        return true;
    }
    
    function _calculateInterestRate(
        AccountType accountType,
        uint256 lockDuration
    ) private pure returns (uint256) {
        uint256 durationBonus;
        unchecked {
            durationBonus = (lockDuration * 100) / SECONDS_PER_YEAR;
        }
        
        uint256 typeBonus;
        if (accountType == AccountType.FIXED_TERM) {
            typeBonus = 200;
        } else if (accountType == AccountType.LADDER_TERM) {
            typeBonus = 300;
        }
        
        return BASE_RATE + durationBonus + typeBonus;
    }
    
    function _calculateSimpleInterest(
        uint256 principal,
        uint256 rate,
        uint256 timeElapsed
    ) private pure returns (uint256) {
        return (principal * rate * timeElapsed) / (BASIS_POINTS * SECONDS_PER_YEAR);
    }
    
    function _calculateCompoundInterest(
        uint256 principal,
        uint256 rate,
        uint256 timeElapsed
    ) private pure returns (uint256) {
        uint256 periods = timeElapsed / SECONDS_PER_YEAR;
        if (periods == 0) return 0;
        
        uint256 ratePerPeriod = rate / BASIS_POINTS;
        uint256 base = 100 + ratePerPeriod;
        
        uint256 compoundedAmount = principal;
        uint256 periodsLength = periods;
        
        for (uint256 i; i < periodsLength;) {
            compoundedAmount = (compoundedAmount * base) / 100;
            unchecked { ++i; }
        }
        
        return compoundedAmount - principal;
    }
    
    function _calculateWithdrawalPenalty(
        uint256 amount,
        Account storage account
    ) private view returns (uint256) {
        if (block.timestamp >= account.lockEndTime) return 0;
        
        uint256 timeRemaining;
        unchecked {
            timeRemaining = account.lockEndTime - block.timestamp;
        }
        uint256 penaltyRate = (timeRemaining * 1000) / SECONDS_PER_YEAR;
        
        if (account.accountType == AccountType.FLEXIBLE_TERM) {
            penaltyRate >>= 1; // Gas efficient division by 2
        }
        
        return (amount * penaltyRate) / BASIS_POINTS;
    }
    
    function getAccountDetails(
        AccountStorage storage self,
        address owner
    ) external view returns (
        uint256 balance,
        uint256 accruedInterest,
        uint256 lockEndTime,
        bool isActive
    ) {
        Account storage account = self.accounts[owner];
        return (
            account.balance,
            account.accruedInterest,
            account.lockEndTime,
            account.isActive
        );
    }
    
    function getRemainingLockTime(
        AccountStorage storage self,
        address owner
    ) external view returns (uint256) {
        Account storage account = self.accounts[owner];
        if (block.timestamp >= account.lockEndTime) return 0;
        unchecked {
            return account.lockEndTime - block.timestamp;
        }
    }
    
    function getTransactionHistory(
        AccountStorage storage self,
        address owner
    ) external view returns (uint256[] memory deposits, uint256[] memory withdrawals) {
        return (self.deposits[owner], self.withdrawals[owner]);
    }
}