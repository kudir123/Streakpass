require("@nomicfoundation/hardhat-ethers");
require("@nomicfoundation/hardhat-verify");
require("dotenv").config();

// Hardhat is used for DEPLOYMENT ONLY (scripts/deploy.js).
// Contracts are compiled and tested with Foundry (see foundry.toml):
//   forge build && forge test
/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.24",
    settings: { optimizer: { enabled: true, runs: 200 } },
  },
  paths: {
    sources: "./contracts",
    tests: "./test-hardhat-unused",
    cache: "./cache-hardhat",
    artifacts: "./artifacts-hardhat",
  },
  networks: {
    bsc: {
      url: process.env.BSC_RPC_URL || "https://bsc-dataseed.binance.org/",
      chainId: 56,
      accounts: process.env.DEPLOYER_PRIVATE_KEY
        ? [process.env.DEPLOYER_PRIVATE_KEY]
        : [],
    },
  },
  etherscan: {
    apiKey: { bsc: process.env.BSCSCAN_API_KEY || "" },
  },
  sourcify: { enabled: false },
};
