// StreakPass deployment to BNB Smart Chain (BSC mainnet, chain id 56).
//
// NOT run as part of the build — run it deliberately when deploying:
//
//   1. Put a funded deployer key in .env (see .env.example):
//        DEPLOYER_PRIVATE_KEY=0x...        (deployer pays ~0.005 BNB gas)
//        BSCSCAN_API_KEY=...               (only needed for verification)
//   2. npx hardhat run scripts/deploy.js --network bsc
//   3. Paste the printed address into frontend/config.js (streakPassAddress).
//   4. Verify on BscScan with the printed constructor argument:
//        npx hardhat verify --network bsc <ADDRESS> 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F
//
// StreakPass has NO admin functions and holds no funds, so the deployer key
// has no power over the contract after deployment. The Agent ID registry
// address below is the constructor's only argument and is immutable.
const { ethers } = require("hardhat");

// SPACE ID Agent ID collection on BNB Chain (ERC-721, symbol "AI").
const AGENT_ID_REGISTRY = "0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F";

async function main() {
  const [deployer] = await ethers.getSigners();
  const network = await ethers.provider.getNetwork();
  if (network.chainId !== 56n) {
    throw new Error(`Refusing to deploy: expected BSC chain id 56, got ${network.chainId}`);
  }
  const balance = await ethers.provider.getBalance(deployer.address);
  console.log("Deployer:        ", deployer.address);
  console.log("Deployer balance:", ethers.formatEther(balance), "BNB");
  if (balance === 0n) throw new Error("Deployer has no BNB for gas.");

  const StreakPass = await ethers.getContractFactory("StreakPass");
  const pass = await StreakPass.deploy(AGENT_ID_REGISTRY);
  await pass.waitForDeployment();

  const address = await pass.getAddress();
  console.log("StreakPass deployed to:", address);
  console.log("Constructor arg (Agent ID registry):", AGENT_ID_REGISTRY);
  console.log("");
  console.log("Next steps:");
  console.log("  1. Put this address in frontend/config.js -> streakPassAddress");
  console.log(`  2. Verify: npx hardhat verify --network bsc ${address} ${AGENT_ID_REGISTRY}`);
  console.log("  3. Sanity check: the contract reports totalUsers() == 0 and");
  console.log("     agentIdRegistry() == the registry address above.");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
