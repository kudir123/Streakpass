# StreakPass — Deployment Record

- **Contract:** StreakPass (badges: StreakPass Badge / SPB)
- **Address:** 0x52db78d410b35f2eeda89deed7a394641da5aba0
- **Chain:** BNB Smart Chain (56)
- **Deploy tx:** 0x57adeda21928c4c8c9d8080b0fff4f45d45f850748d961588f54ca01abe44a13 (block 134333962, status 0x1, gasUsed 1,587,879, cost ≈ 0.00008 BNB at 0.05 gwei)
- **Deployer:** farming wallet 0xc13ac6fa5c89b719c4fb0e626aa78e2a316d9589 (no admin power exists in the contract; deployer is irrelevant after deployment)
- **Constructor arg:** Agent ID registry 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F — verified on-chain via agentIdRegistry() after deployment
- **Deployed code size:** 6,571 bytes — byte-identical size to the locally tested build
- **Source verification:** Sourcify EXACT MATCH (creation + runtime), verified 2026-11-18T15:22:21Z, matchId 59474803 — https://sourcify.dev (contract 56/0x52Db78d410b35F2EedA89deed7a394641Da5aBa0). Sourcify's automatic propagation to Etherscan/BscScan failed on Sourcify's own daily submission quota; retry later or verify on BscScan directly with a free BscScan API key (hackathon asks for BscScan verification specifically).
- **First live interaction:** agentic wallet (Agent ID kudirz92.ai) checkIn() tx 0x3f3a37ff7a0e102b22f990a37e096f855474bdba7f6f25bda7cc8dd621ffcf71 — status 0x1; getStats: streak 1, totalUsers 1. End-to-end product flow proven on mainnet.
- **Frontend:** config.js now carries the deployed address. Hosted on GitHub Pages from the public repo (main branch, /docs folder), enabled by Afriy 2026-11-18 ~22:54 WIB and verified live (HTTP 200): **https://kudir123.github.io/Streakpass/**
- **Repository:** https://github.com/kudir123/Streakpass (public; pushed via the Muse GitHub App — snapshot sync record at ~/workspace/streakpass.muse-github-snapshot-sync.json)

## Pending
1. BscScan verification (retry Sourcify→Etherscan propagation, or a free BscScan/Etherscan API key + `forge verify-contract --verifier etherscan` / hardhat verify). Sourcify exact match already stands as public verification.
2. ≥30 Agent ID addresses interacting before 2026-12-09T08:00Z (Innovation eligibility) — share the live site link.
3. Hackathon submission (project name, website, contract address, Agent ID usage description, reward address).
