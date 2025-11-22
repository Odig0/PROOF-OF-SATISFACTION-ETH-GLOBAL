import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("ProofOfFunCompleteModule", (m) => {
  // Deploy ProofOfFun
  const proofOfFun = m.contract("ProofOfFun", []);

  // Deploy EventManager con recompensas
  const eventManager = m.contract("EventManager", []);

  // Deploy AnonymousVoteToken
  const voteToken = m.contract("AnonymousVoteToken", []);

  // Deploy MerchRedemption
  const merchRedemption = m.contract("MerchRedemption", []);

  // Configurar ProofOfFun con EventManager
  m.call(proofOfFun, "setEventManager", [eventManager]);

  // Note: ProofOfFunFactory excluded due to contract size limits
  // EventRewardToken se crea dinámicamente por EventManager para cada evento

  return { 
    proofOfFun, 
    eventManager, 
    voteToken, 
    merchRedemption 
  };
});
