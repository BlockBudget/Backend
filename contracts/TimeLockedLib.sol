// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title TimeLockedSavingsLib
 * @notice Library implementing time-locked savings functionality with interest mechanisms
 */
library TimeLockedSavingsLib {
    
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
    
    
    function createAccount(
        AccountStorage storage self,
        address owner,
        AccountType accountType,
        InterestType interestType,
        uint256 lockDuration,
        uint256 initialDeposit
    ) external returns (bool) {
        require(initialDeposit > 0, "Invalid initial deposit");
        require(!self.accounts[owner].isActive, "Account already exists");
        
        uint256 interestRate = _calculateInterestRate(accountType, lockDuration);
        
        self.accounts[owner] = Account({
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
    ) external returns (bool) {
        require(self.accounts[owner].isActive, "Account not active");
        require(amount > 0, "Invalid deposit amount");
        
        self.accounts[owner].balance += amount;
        self.deposits[owner].push(amount);
        
        emit DepositReceived(owner, amount, self.accounts[owner].balance);
        
        return true;
    }
    
    function calculateInterest(
        AccountStorage storage self,
        address owner
    ) external returns (uint256) {
        Account storage account = self.accounts[owner];
        require(account.isActive, "Account not active");
        
        uint256 timeElapsed = block.timestamp - account.lastInterestCalculation;
        uint256 interest;
        
        if (account.interestType == InterestType.COMPOUND) {
            interest = _calculateCompoundInterest(
                account.balance,
                account.interestRate,
                timeElapsed
            );
        } else {
            interest = _calculateSimpleInterest(
                account.balance,
                account.interestRate,
                timeElapsed
            );
        }
        
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
    ) external returns (bool) {
        Account storage account = self.accounts[owner];
        require(account.isActive, "Account not active");
        require(amount <= account.balance + account.accruedInterest, "Insufficient balance");
        
        uint256 penalty = 0;
        if (block.timestamp < account.lockEndTime) {
            penalty = _calculateWithdrawalPenalty(amount, account);
        }
        
        uint256 netWithdrawal = amount - penalty;
        account.balance -= amount;
        self.withdrawals[owner].push(netWithdrawal);
        
        emit WithdrawalProcessed(owner, netWithdrawal, penalty);
        
        return true;
    }
    
    function _calculateInterestRate(
        AccountType accountType,
        uint256 lockDuration
    ) private pure returns (uint256) {
        uint256 baseRate = BASE_RATE;
        
        // Add bonus rate based on lock duration (in years)
        uint256 durationBonus = (lockDuration * 100) / SECONDS_PER_YEAR;
        
        // Add bonus based on account type
        uint256 typeBonus;
        if (accountType == AccountType.FIXED_TERM) {
            typeBonus = 200; // +2%
        } else if (accountType == AccountType.LADDER_TERM) {
            typeBonus = 300; // +3%
        }
        
        return baseRate + durationBonus + typeBonus;
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
        for (uint256 i = 0; i < periods; i++) {
            compoundedAmount = (compoundedAmount * base) / 100;
        }
        
        return compoundedAmount - principal;
    }
    
    function _calculateWithdrawalPenalty(
        uint256 amount,
        Account storage account
    ) private view returns (uint256) {
        uint256 timeRemaining = account.lockEndTime - block.timestamp;
        uint256 penaltyRate = (timeRemaining * 1000) / SECONDS_PER_YEAR; // 0.1% per remaining month
        
        if (account.accountType == AccountType.FLEXIBLE_TERM) {
            penaltyRate = penaltyRate / 2; // Half penalty for flexible terms
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
        return account.lockEndTime - block.timestamp;
    }
    
    function getTransactionHistory(
        AccountStorage storage self,
        address owner
    ) external view returns (uint256[] memory deposits, uint256[] memory withdrawals) {
        return (self.deposits[owner], self.withdrawals[owner]);
    }
}