import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const ContractModule = buildModule("BlockBudgetModule", (m) => {
  // Deploy libraries first
  const contributionLib = m.contract("ContributionLib");
  const goalBasedLib = m.contract("GoalBasedLib");
  const timeLockedLib = m.contract("TimeLockedLib");

  // Link libraries to BlockBudget
  const blockBudget = m.contract("BlockBudget", [], {
    libraries: {
      "contracts/ContributionLib.sol:ContributionLib": contributionLib,
      "contracts/GoalBasedLib.sol:GoalBasedLib": goalBasedLib,
      "contracts/TimeLockedLib.sol:TimeLockedLib": timeLockedLib,
    },
  });

  return { blockBudget };
});

export default ContractModule;
