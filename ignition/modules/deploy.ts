import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const ContractModule = buildModule("BlockBudgetFactoryModule", (m) => {
   
  const contributionLib = m.contract("ContributionLib");
  const walletLib = m.contract("WalletLibrary");
  //const blockBudget = m.contract("BlockBudget", []);

   
  const blockBudgetFactory = m.contract("BlockBudgetFactory",[],{
    libraries: {
      ContributionLib: contributionLib,
      WalletLibrary: walletLib,
    },
  
  });

  return { blockBudgetFactory };
});

export default ContractModule;
