# StreakPass — build notes

Built 2026-11-18 (local build only — nothing deployed, nothing broadcast,
nothing pushed).

## Toolchain

- forge 1.7.1 (Foundry, `~/.foundry/bin`), solc **0.8.24** (pinned in
  `foundry.toml`), optimizer **on, 200 runs**, EVM paris.
- Node v24.22.1 used only for JS syntax checks (`node --check`) and the
  static frontend smoke test. Hardhat deploy script was written but, per the
  brief, **not run** (no `npm install` performed; it is deploy-ready).

## Compile

`forge build` — clean. Compiles 3 files (StreakPass, MockAgentId, test).
No solc warnings on the final sources.

- **StreakPass deployed bytecode size: 6,571 bytes** (creation: 6,914) —
  well under the 24,576-byte EIP-170 limit.
- One fix during the build: `MILESTONES` was first declared as a
  `constant` array, which Solidity rejects ("Only constants of value type
  and byte array type are implemented"). It is now a fixed array initialised
  at declaration and never written after deployment.
- The base64 helper was rewritten once before first compile (an assembly
  draft misused `byte()` on a pointer); final version is plain Solidity and
  is verified end-to-end below.

## Tests

`forge test` — **10 passed, 0 failed, 0 skipped.** The suite uses a minimal
inline cheatcode interface, so it has zero external dependencies (no
forge-std download needed).

| Test | Covers |
|---|---|
| test_CheckInRevertsWithoutAgentId | (a) no Agent ID → `NoAgentId` |
| test_FirstCheckIn | (b) streak 1, totalUsers 1, CheckIn event |
| test_SameDaySecondCheckInReverts | (c) `AlreadyCheckedInToday` |
| test_NextDayStreakTwo | (d) consecutive day → streak 2 |
| test_SkippedDayResetsStreakKeepsLongest | (e) gap → streak 1, longest kept |
| test_BadgeMintsAtStreakThreeOnlyOnce | (f) badge at 3, BadgeMinted event, no re-mint, tokenURI renders |
| test_BadgeMintsAtStreakSeven | second milestone, mask bits 0+1 |
| test_BadgeTransferReverts | (g) transferFrom / safeTransferFrom / approve / setApprovalForAll → `Soulbound` |
| test_TwoUsersIndependent | (h) independent stats, globals add up |
| test_ViewsForFreshUser | zeroed views, hasAgentId / checkedInToday |

## End-to-end verification on a local anvil node (not mainnet)

Deployed MockAgentId + StreakPass locally, minted a mock Agent ID, checked
in on 3 consecutive (time-warped) days:

- `getStats` → currentStreak 3, longestStreak 3, totalCheckIns 3,
  badgesMask 1 (3-day badge bit set).
- `tokenURI(1)` decoded in Python: valid JSON, name
  "StreakPass Badge - 3-Day Streak", attributes correct, embedded
  `data:image/svg+xml;base64` image decodes to the bronze badge SVG.

Tooling quirks found on this machine (for whoever deploys later):
`forge create` needed `--broadcast` (1.7.1 dry-runs by default) and behaved
inconsistently against the local node, so the local verification deployed
via `cast send --create` with bytecode taken from the forge artifact —
worked first try. This does not affect the Hardhat deploy script.

## Frontend smoke test

- `node --check` passes on `app.js`, `config.js`, `scripts/deploy.js`,
  `hardhat.config.js`.
- Served `frontend/` with `python3 -m http.server`: index.html, app.js,
  style.css, config.js all HTTP 200.
- The page is static-first: all explanatory content is plain HTML; app.js
  guards every dynamic step (missing wallet, missing ethers CDN, wrong
  network, undeployed contract → labelled preview mode with check-in
  disabled and the reason shown).

## Deployment blockers / next steps

None in the code. To deploy, someone must:

1. `cp .env.example .env` and add a deployer key funded with a little BNB
   (deployment is one small contract; ~0.005 BNB is ample).
2. `npm install && npm run deploy:bsc`.
3. Paste the address into `frontend/config.js`, verify on BscScan with the
   command the script prints, and host `frontend/` anywhere static.
4. Hackathon submission (by 2026-12-09T08:00Z) needs: project name, website,
   contract address, Agent ID usage description — the README's "How Agent
   ID is used" section is written to be lifted into that form.
5. Innovation Award eligibility needs ≥30 Agent ID addresses to interact
   with the contract during the submission window — a community step, not a
   code step.
