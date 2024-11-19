import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import hre from "hardhat";
import  "../contracts/ContributionLib.sol";
import  "../contracts/TimeLockedLib.sol";
import  "../contracts/GoalBasedLib.sol"



describe("BlockBudget", function () {
  async function deployBlockBudgetFixture() {
    const [owner, user1, user2] = await hre.ethers.getSigners();

    const BlockBudgetFactory = await hre.ethers.getContractFactory("BlockBudget");
    const blockBudget = await BlockBudgetFactory.deploy();

    return { blockBudget, owner, user1, user2 };
  }

  describe("User Registration", function () {
    it("Should allow a user to register", async function () {
      const { blockBudget, user1 } = await loadFixture(deployBlockBudgetFixture);
      console.log(blockBudget);

      const userName = "Test User";
      await blockBudget.connect(user1).registerUser(userName);

      const userProfile = await blockBudget.getUserProfile(user1.address);
      expect(userProfile.name).to.equal(userName);
      expect(userProfile.isRegistered).to.be.true;
      expect(userProfile.userAddress).to.equal(user1.address);
    });

    it("Should prevent registering an already registered user", async function () {
      const { blockBudget, user1 } = await loadFixture(deployBlockBudgetFixture);

      await blockBudget.connect(user1).registerUser("Test User");
      await expect(blockBudget.connect(user1).registerUser("Another Name"))
        .to.be.revertedWith("User already registered");
    });

    it("Should prevent registering with an empty name", async function () {
      const { blockBudget, user1 } = await loadFixture(deployBlockBudgetFixture);

      await expect(blockBudget.connect(user1).registerUser(""))
        .to.be.revertedWith("Name cannot be empty");
    });
  });

  describe("Time Locked Accounts", function () {
    it("Should create a time-locked account", async function () {
      const { blockBudget, user1 } = await loadFixture(deployBlockBudgetFixture);

      await blockBudget.connect(user1).registerUser("Test User");

      await blockBudget.connect(user1).createTimeLockedAccount(
        0, // AccountType (enum value)
        0, // InterestType (enum value)
        30 * 24 * 60 * 60, // 30 days lock duration
        hre.ethers.parseEther("1")
      );

      const accountDetails = await blockBudget.getTimeLockedAccountDetails(user1.address);
      expect(accountDetails.balance).to.equal(hre.ethers.parseEther("1"));
      expect(accountDetails.isActive).to.be.true;
    });

    it("Should allow deposit to time-locked account", async function () {
      const { blockBudget, user1 } = await loadFixture(deployBlockBudgetFixture);

      await blockBudget.connect(user1).registerUser("Test User");
      await blockBudget.connect(user1).createTimeLockedAccount(
        0, 0, 30 * 24 * 60 * 60, hre.ethers.parseEther("1")
      );

      await blockBudget.connect(user1).deposit(hre.ethers.parseEther("0.5"));
      const accountDetails = await blockBudget.getTimeLockedAccountDetails(user1.address);
      expect(accountDetails.balance).to.equal(hre.ethers.parseEther("1.5"));
    });
  });

  // describe("Savings Goals", function () {
  //   it("Should create a savings goal", async function () {
  //     const { blockBudget, user1 } = await loadFixture(deployBlockBudgetFixture);

  //     await blockBudget.connect(user1).registerUser("Test User");

  //     const goalName = "Emergency Fund";
  //     const goalId = await blockBudget.connect(user1).createSavingsGoal(
  //       goalName,
  //       hre.ethers.parseEther("10"),  
  //       Math.floor(Date.now() / 1000) + 365 * 24 * 60 * 60,
  //       0, // GoalType (enum)
  //       1, // SavingFrequency (enum)
  //       hre.ethers.parseEther("0.1"),  
  //       true, // Flexible
  //       true, // Auto contribute
  //       10 // Penalty rate
  //     );

  //     const goalDetails = await blockBudget.getGoalDetails(await goalId.wait().then(tx => tx?.logs[0].args[0]));
  //     expect(goalDetails.name).to.equal(goalName);
  //     expect(goalDetails.targetAmount).to.equal(hre.ethers.parseEther("10"));
  //   });

  //   it("Should add a milestone to a savings goal", async function () {
  //     const { blockBudget, user1 } = await loadFixture(deployBlockBudgetFixture);
  //     await blockBudget.connect(user1).registerUser("Test User");

  //     const goalId = await blockBudget.connect(user1).createSavingsGoal(
  //       "Emergency Fund",
  //       hre.ethers.parseEther("10"),
  //       Math.floor(Date.now() / 1000) + 365 * 24 * 60 * 60,
  //       0, 1, hre.ethers.parseEther("0.1"), true, true, 10
  //     );

  //     const milestoneId = await blockBudget.connect(user1).defineSavingsMilestone(
  //       await goalId.wait().then(tx => tx?.logs[0].args[0]),
  //       "First Quarter Savings",
  //       hre.ethers.parseEther("2.5"),
  //       Math.floor(Date.now() / 1000) + 90 * 24 * 60 * 60,
  //       hre.ethers.parseEther("0.1")
  //     );

  //     const milestoneDetails = await blockBudget.getMilestoneDetails(
  //       await goalId.wait().then(tx => tx?.logs[0].args[0]),
  //       await milestoneId.wait().then(tx => tx?.logs[0].args[0])
  //     );
  //     expect(milestoneDetails.description).to.equal("First Quarter Savings");
  //   });
  // });

  // describe("Contribution Campaigns", function () {
  //   it("Should create a contribution campaign", async function () {
  //     const { blockBudget, user1 } = await loadFixture(deployBlockBudgetFixture);

  //     // Register user
  //     await blockBudget.connect(user1).registerUser("Campaign Creator");

  //     // Create campaign
  //     const campaignId = await blockBudget.connect(user1).createCampaign(
  //       "Community Project",
  //       "Fundraising for local school",
  //       hre.ethers.parseEther("5"),
  //       30 * 24 * 60 * 60, // 30 days
  //       false // public campaign
  //     );

  //     const campaignDetails = await blockBudget.getCampaignDetails(
  //       await campaignId.wait().then(tx => tx?.logs[0].args[0])
  //     );
  //     expect(campaignDetails.name).to.equal("Community Project");
  //     expect(campaignDetails.targetAmount).to.equal(hre.ethers.parseEther("5"));
  //   });

  //   it("Should allow contribution to a campaign", async function () {
  //     const { blockBudget, user1, user2 } = await loadFixture(deployBlockBudgetFixture);

  //     await blockBudget.connect(user1).registerUser("Campaign Creator");
  //     await blockBudget.connect(user2).registerUser("Contributor");

  //     const campaignId = await blockBudget.connect(user1).createCampaign(
  //       "Community Project",
  //       "Fundraising for local school",
  //       hre.ethers.parseEther("5"),
  //       30 * 24 * 60 * 60,
  //       false
  //     );

  //     await blockBudget.connect(user2).contributeToCompaign(
  //       await campaignId.wait().then(tx => tx?.logs[0].args[0]), 
  //       { value: hre.ethers.parseEther("0.5") }
  //     );

  //     const contributionAmount = await blockBudget.getContribution(
  //       await campaignId.wait().then(tx => tx?.logs[0].args[0]), 
  //       user2.address
  //     );
  //     expect(contributionAmount).to.equal(hre.ethers.parseEther("0.5"));
  //   });
  // });
});