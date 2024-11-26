import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const ContractModule = buildModule("BlockBudgetFactoryModule", (m) => {
   
  const contributionLib = m.contract("ContributionLib");
  const walletLib = m.contract("WalletLibrary");
   
  const blockBudgetFactory = m.contract("BlockBudgetFactory",[],{
    libraries: {
      ContributionLib: contributionLib,
      WalletLibrary: walletLib,
    },
  });

  const addr = "0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9";

  const defiStaking = m.contract("DefiStaking", [addr]);

  return { blockBudgetFactory, defiStaking };
});

export default ContractModule;
