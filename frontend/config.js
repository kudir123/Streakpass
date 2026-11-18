// StreakPass frontend configuration.
// After deployment, paste the StreakPass contract address below and the page
// goes fully live. Until then the page renders in "not deployed yet" mode.
window.STREAKPASS_CONFIG = {
  // === DEPLOYMENT: replace this placeholder with the deployed address ===
  streakPassAddress: "0x52db78d410b35f2eeda89deed7a394641da5aba0",
  // =======================================================================

  // SPACE ID Agent ID collection on BNB Chain (the access key).
  agentIdRegistryAddress: "0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F",

  chainId: 56,
  chainIdHex: "0x38",
  chainName: "BNB Smart Chain",
  rpcUrl: "https://bsc-dataseed.binance.org/",
  blockExplorerUrl: "https://bscscan.com",
  nativeCurrency: { name: "BNB", symbol: "BNB", decimals: 18 },

  milestones: [3, 7, 14, 30],

  // Minimal ABIs — only the functions the page calls.
  registryAbi: [
    "function balanceOf(address owner) view returns (uint256)",
  ],
  streakPassAbi: [
    "function checkIn()",
    "function hasAgentId(address user) view returns (bool)",
    "function checkedInToday(address user) view returns (bool)",
    "function getStats(address user) view returns (uint256 currentStreak, uint256 longestStreak, uint256 totalCheckIns, uint256 lastCheckInDay, uint256 badgesMask)",
    "function totalUsers() view returns (uint256)",
    "function totalCheckIns() view returns (uint256)",
    "function balanceOf(address owner) view returns (uint256)",
  ],
};
