// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

library WalletLibrary {
    struct UserProfile {
        string name;
        address userAddress;
        uint256 registrationDate;
        bool isRegistered;
    }

    struct Transaction {
        address sender;
        address recipient;
        uint256 amount;
        uint256 timestamp;
        string transactionType;
    }

    struct Wallet {
        uint256 balance;
        Transaction[] transactions;
        UserProfile user;
    }

    event UserRegistered(address indexed user, string name, uint256 timestamp);
    event Deposit(address indexed user, uint256 amount);
    event Withdrawal(address indexed user, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 amount);

    function registerUser(
        mapping(address => UserProfile) storage userProfiles, 
        string memory name
    ) external {
        require(!userProfiles[msg.sender].isRegistered, "User already registered");
        require(bytes(name).length > 0, "Name cannot be empty");

        userProfiles[msg.sender] = UserProfile({
            name: name,
            userAddress: msg.sender,
            registrationDate: block.timestamp,
            isRegistered: true
        });

        emit UserRegistered(msg.sender, name, block.timestamp);
    }

    function deposit(
        mapping(address => Wallet) storage wallets
    ) external {
        require(msg.value > 0, "Deposit amount must be positive");
        
        Wallet storage wallet = wallets[msg.sender];
        wallet.balance += msg.value;
        
        wallet.transactions.push(Transaction({
            sender: address(0),
            recipient: msg.sender,
            amount: msg.value,
            timestamp: block.timestamp,
            transactionType: "deposit"
        }));
        
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(
        mapping(address => Wallet) storage wallets,
        uint256 amount
    ) external {
        Wallet storage wallet = wallets[msg.sender];
        
        require(amount > 0, "Withdrawal amount must be positive");
        require(wallet.balance >= amount, "Insufficient balance");
        
        wallet.balance -= amount;
        
        wallet.transactions.push(Transaction({
            sender: msg.sender,
            recipient: address(0),
            amount: amount,
            timestamp: block.timestamp,
            transactionType: "withdrawal"
        }));
        
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");
        
        emit Withdrawal(msg.sender, amount);
    }

    function transfer(
        mapping(address => Wallet) storage wallets,
        address recipient, 
        uint256 amount
    ) external {
        Wallet storage senderWallet = wallets[msg.sender];
        
        require(recipient != address(0), "Invalid recipient");
        require(amount > 0, "Transfer amount must be positive");
        require(senderWallet.balance >= amount, "Insufficient balance");
        
        senderWallet.balance -= amount;
        
        senderWallet.transactions.push(Transaction({
            sender: msg.sender,
            recipient: recipient,
            amount: amount,
            timestamp: block.timestamp,
            transactionType: "transfer"
        }));
        
        (bool success, ) = payable(recipient).call{value: amount}("");
        require(success, "Transfer failed");
        
        emit Transfer(msg.sender, recipient, amount);
    }

    function getBalance(
        mapping(address => Wallet) storage wallets
    ) external view returns (uint256) {
        return wallets[msg.sender].balance;
    }

    function getTransactionHistory(
        mapping(address => Wallet) storage wallets
    ) external view returns (Transaction[] memory) {
        return wallets[msg.sender].transactions;
    }
}