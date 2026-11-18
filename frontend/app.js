// StreakPass frontend logic. Everything degrades gracefully: the static page
// renders fully even with no wallet, no network, or no deployment yet.
(function () {
  "use strict";
  var CFG = window.STREAKPASS_CONFIG || {};
  var ZERO = "0x0000000000000000000000000000000000000000";
  var deployed = CFG.streakPassAddress && CFG.streakPassAddress.toLowerCase() !== ZERO;
  var TIERS = { 3: "Bronze", 7: "Silver", 14: "Gold", 30: "Diamond" };

  var el = function (id) { return document.getElementById(id); };
  var connectBtn = el("connect-btn"), switchBtn = el("switch-btn"),
      checkinBtn = el("checkin-btn"), note = el("checkin-note"),
      status = el("wallet-status");

  var provider = null, signer = null, account = null;
  var pass = null, registry = null;

  // --- Static badge shelf (renders before any wallet interaction) --------
  function renderShelf(mask) {
    var shelf = el("badge-shelf");
    shelf.innerHTML = "";
    (CFG.milestones || [3, 7, 14, 30]).forEach(function (m, i) {
      var earned = mask != null && (Number(mask) & (1 << i)) !== 0;
      var d = document.createElement("div");
      d.className = "badge" + (earned ? " earned" : "");
      d.innerHTML = '<span class="days">' + m + '</span>day streak<br><span class="tier">' +
        (TIERS[m] || "") + (earned ? " · earned" : " · locked") + "</span>";
      shelf.appendChild(d);
    });
  }
  renderShelf(null);
  if (!deployed) el("deploy-note").classList.remove("hidden");

  function setNote(t) { note.textContent = t || ""; }

  // --- Read-only global counters (no wallet needed) ----------------------
  async function loadGlobals() {
    if (!deployed || typeof ethers === "undefined") return;
    try {
      var ro = new ethers.JsonRpcProvider(CFG.rpcUrl);
      var c = new ethers.Contract(CFG.streakPassAddress, CFG.streakPassAbi, ro);
      el("global-users").textContent = String(await c.totalUsers());
      el("global-checkins").textContent = String(await c.totalCheckIns());
    } catch (e) { /* counters stay as dashes; static page unaffected */ }
  }
  loadGlobals();

  // --- Network helpers ----------------------------------------------------
  async function currentChainId() {
    var hex = await window.ethereum.request({ method: "eth_chainId" });
    return parseInt(hex, 16);
  }

  async function ensureNetwork() {
    if ((await currentChainId()) === CFG.chainId) {
      switchBtn.classList.add("hidden");
      return true;
    }
    switchBtn.classList.remove("hidden");
    status.textContent = "Wrong network — StreakPass lives on BNB Smart Chain (chain 56).";
    return false;
  }

  switchBtn.addEventListener("click", async function () {
    try {
      await window.ethereum.request({
        method: "wallet_switchEthereumChain",
        params: [{ chainId: CFG.chainIdHex }],
      });
    } catch (err) {
      if (err && err.code === 4902) {
        await window.ethereum.request({
          method: "wallet_addEthereumChain",
          params: [{
            chainId: CFG.chainIdHex, chainName: CFG.chainName,
            rpcUrls: [CFG.rpcUrl], blockExplorerUrls: [CFG.blockExplorerUrl],
            nativeCurrency: CFG.nativeCurrency,
          }],
        });
      } else { return; }
    }
    refresh();
  });

  // --- Wallet -------------------------------------------------------------
  connectBtn.addEventListener("click", async function () {
    if (typeof window.ethereum === "undefined") {
      status.textContent = "No wallet extension found. Open this page in a browser with a wallet (for example the Binance Wallet or MetaMask) to connect.";
      return;
    }
    if (typeof ethers === "undefined") {
      status.textContent = "The ethers library failed to load — check your connection and reload.";
      return;
    }
    try {
      provider = new ethers.BrowserProvider(window.ethereum);
      var accounts = await provider.send("eth_requestAccounts", []);
      account = accounts[0];
      signer = await provider.getSigner();
      status.textContent = "Connected: " + account.slice(0, 6) + "…" + account.slice(-4);
      connectBtn.classList.add("hidden");
      if (await ensureNetwork()) refresh();
    } catch (e) {
      status.textContent = "Connection rejected in the wallet.";
    }
  });

  async function refresh() {
    if (!provider || !account) return;
    el("passport").classList.remove("hidden");
    registry = new ethers.Contract(CFG.agentIdRegistryAddress, CFG.registryAbi, provider);
    try {
      var bal = await registry.balanceOf(account);
      var held = bal > 0n;
      el("agentid-status").textContent = held ? "held ✓ — your key works" : "not held ✗";
      if (!held) {
        checkinBtn.disabled = true;
        setNote("This wallet holds no Agent ID, so it cannot check in. An Agent ID is claimed inside the Binance app (Wallet → Agent ID banner), one per user, free and non-transferable.");
        return;
      }
    } catch (e) {
      el("agentid-status").textContent = "could not be read (network hiccup) — reload to retry";
      return;
    }

    if (!deployed) {
      checkinBtn.disabled = true;
      setNote("Your Agent ID is ready. Check-in activates when the StreakPass contract is deployed.");
      return;
    }

    pass = new ethers.Contract(CFG.streakPassAddress, CFG.streakPassAbi, signer);
    try {
      var s = await pass.getStats(account);
      el("stat-streak").textContent = String(s.currentStreak);
      el("stat-longest").textContent = String(s.longestStreak);
      el("stat-total").textContent = String(s.totalCheckIns);
      el("stat-badges").textContent = String(await pass.balanceOf(account));
      renderShelf(s.badgesMask);
      var done = await pass.checkedInToday(account);
      if (done) {
        checkinBtn.disabled = true;
        setNote("Already checked in today — come back tomorrow (UTC) to extend your streak.");
      } else {
        checkinBtn.disabled = false;
        setNote(s.totalCheckIns > 0n && s.currentStreak === 0n
          ? "A new day, a fresh start: today's check-in begins a new streak."
          : "One tap, one day on the passport. Gas on BNB Chain is a fraction of a cent.");
      }
      loadGlobals();
    } catch (e) {
      setNote("Could not load your passport stats — reload to retry.");
    }
  }

  checkinBtn.addEventListener("click", async function () {
    if (!pass) return;
    checkinBtn.disabled = true;
    setNote("Waiting for you to confirm the check-in in your wallet…");
    try {
      var tx = await pass.checkIn();
      setNote("Check-in sent — waiting for the block…");
      await tx.wait();
      setNote("Checked in. See you tomorrow to keep the streak alive.");
      refresh();
    } catch (e) {
      checkinBtn.disabled = false;
      setNote("Check-in did not go through (" + (e && e.shortMessage ? e.shortMessage : "rejected or failed") + "). Nothing was charged beyond possible gas for a reverted attempt — check the note above your stats and try again.");
    }
  });

  if (typeof window.ethereum !== "undefined" && window.ethereum.on) {
    window.ethereum.on("accountsChanged", function () { window.location.reload(); });
    window.ethereum.on("chainChanged", function () { window.location.reload(); });
  }
})();
