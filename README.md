# StreakPass

**The daily check-in passport for Agent ID holders, on BNB Chain.**

StreakPass is a small on-chain ritual. Your **Agent ID is the key**: if your
wallet holds an Agent ID, you can check in **once per UTC day**. Check in on
consecutive days to build a **streak**; miss a day and the running streak
restarts at 1 (your longest streak is kept forever). Reaching a streak of
**3, 7, 14 or 30 days** mints a **soulbound badge** (Bronze, Silver, Gold,
Diamond) that can never be sold, traded or transferred.

Built for the Binance Wallet × BNB Chain **Agent ID Hackathon**
(submission window 18 Nov – 9 Dec 2026).

## How Agent ID is used — the core flow, not decoration

Agent ID (the SPACE ID Agent ID ERC-721 collection at
`0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F` on BNB Chain) is the access
control for the product's only action:

- `StreakPass.checkIn()` calls `balanceOf(msg.sender)` on the Agent ID
  registry **live, on every check-in**. No Agent ID → the call reverts with
  `NoAgentId()`. There is no allowlist, no signature scheme and no other way
  in: holding the identity *is* the permission.
- The registry address is set once in the constructor and is **immutable**,
  so the key can never be swapped after deployment.
- The frontend reads the same registry to show "Agent ID: held / not held"
  before the user ever signs anything, and explains exactly how to claim an
  Agent ID (in the Binance app) when the wallet doesn't hold one.

Because one person can claim only one Agent ID and it is non-transferable,
a streak on StreakPass is tied to a persistent identity, not to a disposable
wallet — that is what makes the passport meaningful.

## Contract design

One self-contained contract, `contracts/StreakPass.sol` (Solidity 0.8.24,
no external dependencies — the registry interface is defined inline):

- **Check-ins** — one per UTC day (`block.timestamp / 86400`). Tracks
  `currentStreak`, `longestStreak`, `totalCheckIns`, `lastCheckInDay` per
  user, plus global `totalUsers` / `totalCheckIns`. Emits
  `CheckIn(user, day, streak)`.
- **Badges** — a minimal ERC-721 ("StreakPass Badge", symbol `SPB`)
  implemented inside the same contract. A badge mints automatically the
  moment a streak reaches 3, 7, 14 or 30; each milestone mints at most once
  per user (bitmask). `tokenURI` returns a `data:application/json` URI with
  an inline SVG per milestone. **Soulbound:** `transferFrom`,
  both `safeTransferFrom` overloads, `approve` and `setApprovalForAll` all
  revert with `Soulbound()`. Emits `BadgeMinted(user, milestone, tokenId)`
  and the standard ERC-721 mint `Transfer`.
- **Views** — `getStats(user)`, `hasAgentId(user)`, `checkedInToday(user)`.

### Permissions: none, by design

StreakPass has **no owner and no admin functions of any kind**. There is no
privileged mint, no pause, no upgrade path, no fee switch and no withdrawal.
`checkIn()` is nonpayable and the contract never holds funds. The deployer
has exactly as much power over StreakPass as anyone else: none. The only way
a badge can ever exist is a holder checking in on consecutive days.

## Repository layout

```
contracts/StreakPass.sol        the whole product: check-ins + soulbound badges
contracts/mocks/MockAgentId.sol mintable ERC-721 stub standing in for the registry
test/StreakPass.t.sol           Foundry test suite (10 tests)
frontend/                       static page: index.html + app.js + style.css + config.js
scripts/deploy.js               Hardhat deployment script for BSC (not run during build)
foundry.toml                    Foundry profile (solc 0.8.24, optimizer 200 runs)
hardhat.config.js               Hardhat config, deployment only
```

## Run the tests

Requires [Foundry](https://book.getfoundry.sh/getting-started/installation).

```bash
forge build
forge test
```

The suite covers: check-in reverts without an Agent ID; first check-in sets
streak 1 and `totalUsers` 1; same-day second check-in reverts; next-day
check-in reaches streak 2; a skipped day resets the streak while keeping
`longestStreak`; the badge mints exactly at streak 3 and never twice; badges
at streak 7; badge transfers/approvals revert; two users progress
independently; fresh-user views are zeroed.

## Frontend

No build step — serve the folder statically:

```bash
cd frontend && python3 -m http.server 8080
```

The page connects a wallet (`window.ethereum`), switches to BNB Smart Chain
(56) when needed, reads the Agent ID registry directly, shows streak stats
and the badge shelf, and enables the Check In button only when the wallet is
eligible and hasn't checked in today. Before deployment it renders in a
clearly-labelled preview mode (see `frontend/config.js`).

## Deploy (when ready)

1. Create `.env` from `.env.example` with a funded deployer key.
2. `npm install`
3. `npm run deploy:bsc` — deploys with the Agent ID registry as the only
   constructor argument, prints the address and verification command.
4. Put the deployed address in `frontend/config.js` (`streakPassAddress`).
5. Verify the source on BscScan with the printed command, so the contract is
   public and open-source as the hackathon requires.

## License

MIT — see [LICENSE](LICENSE).
