import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const ContractModule = buildModule("LockModule", (m) => {
   
  const contract = m.contract("Lock", []);

  return { contract };
});

export default ContractModule;
