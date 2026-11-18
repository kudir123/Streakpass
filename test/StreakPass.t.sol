// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {StreakPass} from "../contracts/StreakPass.sol";
import {MockAgentId} from "../contracts/mocks/MockAgentId.sol";

/// @dev Minimal cheatcode interface so the suite needs no external libraries.
interface Vm {
    function warp(uint256 newTimestamp) external;
    function prank(address newSender) external;
    function expectRevert(bytes4 revertData) external;
    function expectRevert() external;
    function expectEmit(bool checkTopic1, bool checkTopic2, bool checkTopic3, bool checkData) external;
}

contract StreakPassTest {
    Vm internal constant vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    // Events mirrored for expectEmit checks.
    event CheckIn(address indexed user, uint256 day, uint256 streak);
    event BadgeMinted(address indexed user, uint256 milestone, uint256 tokenId);

    uint256 internal constant DAY = 86400;
    // A clean UTC day boundary to start from (day 20000 after the epoch).
    uint256 internal constant DAY0 = 20000 * DAY;

    MockAgentId internal registry;
    StreakPass internal pass;

    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);
    address internal carol = address(0xCA401); // never holds an Agent ID

    function setUp() public {
        registry = new MockAgentId();
        pass = new StreakPass(address(registry));
        registry.mint(alice);
        registry.mint(bob);
        vm.warp(DAY0 + 3600); // 01:00 UTC on day 20000
    }

    // -- assertion helpers (no forge-std dependency) --------------------

    function assertEq(uint256 a, uint256 b, string memory what) internal pure {
        if (a != b) revert(string.concat("assertEq failed: ", what));
    }

    function assertTrue(bool cond, string memory what) internal pure {
        if (!cond) revert(string.concat("assertTrue failed: ", what));
    }

    function _checkInAs(address user) internal {
        vm.prank(user);
        pass.checkIn();
    }

    function _checkInDays(address user, uint256 startDay, uint256 count) internal {
        for (uint256 i = 0; i < count; i++) {
            vm.warp((startDay + i) * DAY + 3600);
            _checkInAs(user);
        }
    }

    // -- (a) check-in reverts without an Agent ID ------------------------

    function test_CheckInRevertsWithoutAgentId() public {
        assertTrue(!pass.hasAgentId(carol), "carol has no Agent ID");
        vm.prank(carol);
        vm.expectRevert(StreakPass.NoAgentId.selector);
        pass.checkIn();
    }

    // -- (b) first check-in: streak 1, totalUsers 1 ----------------------

    function test_FirstCheckIn() public {
        vm.expectEmit(true, false, false, true);
        emit CheckIn(alice, 20000, 1);
        _checkInAs(alice);

        (uint256 cur, uint256 longest, uint256 total, uint256 lastDay, uint256 mask) = pass.getStats(alice);
        assertEq(cur, 1, "currentStreak");
        assertEq(longest, 1, "longestStreak");
        assertEq(total, 1, "user totalCheckIns");
        assertEq(lastDay, 20000, "lastCheckInDay");
        assertEq(mask, 0, "badgesMask");
        assertEq(pass.totalUsers(), 1, "global totalUsers");
        assertEq(pass.totalCheckIns(), 1, "global totalCheckIns");
        assertTrue(pass.checkedInToday(alice), "checkedInToday");
    }

    // -- (c) same-day second check-in reverts ----------------------------

    function test_SameDaySecondCheckInReverts() public {
        _checkInAs(alice);
        vm.warp(DAY0 + 7200); // later the same UTC day
        vm.prank(alice);
        vm.expectRevert(StreakPass.AlreadyCheckedInToday.selector);
        pass.checkIn();
    }

    // -- (d) next-day check-in: streak 2 ---------------------------------

    function test_NextDayStreakTwo() public {
        _checkInAs(alice);
        vm.warp(DAY0 + DAY + 3600);
        _checkInAs(alice);

        (uint256 cur, uint256 longest, uint256 total,,) = pass.getStats(alice);
        assertEq(cur, 2, "currentStreak");
        assertEq(longest, 2, "longestStreak");
        assertEq(total, 2, "user totalCheckIns");
        assertEq(pass.totalUsers(), 1, "still one user");
    }

    // -- (e) skipped day resets streak, longest kept ---------------------

    function test_SkippedDayResetsStreakKeepsLongest() public {
        _checkInDays(alice, 20000, 3); // days 20000, 20001, 20002 -> streak 3
        (uint256 cur, uint256 longest,,,) = pass.getStats(alice);
        assertEq(cur, 3, "streak 3 before gap");
        assertEq(longest, 3, "longest 3 before gap");

        // Skip day 20003 entirely; check in on 20004.
        vm.warp(20004 * DAY + 3600);
        _checkInAs(alice);

        (cur, longest,,,) = pass.getStats(alice);
        assertEq(cur, 1, "streak resets to 1 after gap");
        assertEq(longest, 3, "longestStreak kept");
    }

    // -- (f) badge mints exactly at streak 3, and only once --------------

    function test_BadgeMintsAtStreakThreeOnlyOnce() public {
        _checkInDays(alice, 20000, 2); // streak 1, 2
        assertEq(pass.balanceOf(alice), 0, "no badge before streak 3");

        // Third consecutive day: badge for milestone 3, tokenId 1.
        vm.warp(20002 * DAY + 3600);
        vm.expectEmit(true, false, false, true);
        emit BadgeMinted(alice, 3, 1);
        _checkInAs(alice);

        assertEq(pass.balanceOf(alice), 1, "one badge after streak 3");
        assertTrue(pass.ownerOf(1) == alice, "badge 1 owned by alice");
        (,,,, uint256 mask) = pass.getStats(alice);
        assertEq(mask, 1, "mask bit 0 set");

        // Days 4..6: no re-mint of the 3-day badge.
        _checkInDays(alice, 20003, 3);
        assertEq(pass.balanceOf(alice), 1, "3-day badge not minted twice");

        // tokenURI renders and names the milestone.
        string memory uri = pass.tokenURI(1);
        assertTrue(bytes(uri).length > 100, "tokenURI non-trivial");
    }

    function test_BadgeMintsAtStreakSeven() public {
        _checkInDays(alice, 20000, 7);
        assertEq(pass.balanceOf(alice), 2, "badges for 3 and 7");
        (,,,, uint256 mask) = pass.getStats(alice);
        assertEq(mask, 3, "mask bits 0 and 1 set");
        assertTrue(pass.ownerOf(2) == alice, "badge 2 owned by alice");
    }

    // -- (g) badge transfer / approval reverts (soulbound) ---------------

    function test_BadgeTransferReverts() public {
        _checkInDays(alice, 20000, 3);
        vm.prank(alice);
        vm.expectRevert(StreakPass.Soulbound.selector);
        pass.transferFrom(alice, bob, 1);

        vm.prank(alice);
        vm.expectRevert(StreakPass.Soulbound.selector);
        pass.safeTransferFrom(alice, bob, 1);

        vm.prank(alice);
        vm.expectRevert(StreakPass.Soulbound.selector);
        pass.approve(bob, 1);

        vm.prank(alice);
        vm.expectRevert(StreakPass.Soulbound.selector);
        pass.setApprovalForAll(bob, true);
    }

    // -- (h) two users are independent -----------------------------------

    function test_TwoUsersIndependent() public {
        _checkInDays(alice, 20000, 3); // alice: streak 3 + badge
        _checkInAs(bob); // bob checks in on day 20002 (his first)

        (uint256 aCur,,,,) = pass.getStats(alice);
        (uint256 bCur, uint256 bLongest, uint256 bTotal,,) = pass.getStats(bob);
        assertEq(aCur, 3, "alice streak");
        assertEq(bCur, 1, "bob streak");
        assertEq(bLongest, 1, "bob longest");
        assertEq(bTotal, 1, "bob total");
        assertEq(pass.balanceOf(bob), 0, "bob has no badge");
        assertEq(pass.totalUsers(), 2, "two users");
        assertEq(pass.totalCheckIns(), 4, "four check-ins total");
    }

    // -- extra: views for a user who never checked in --------------------

    function test_ViewsForFreshUser() public view {
        assertTrue(pass.hasAgentId(alice), "alice holds Agent ID");
        assertTrue(!pass.checkedInToday(alice), "not checked in yet");
        (uint256 cur, uint256 longest, uint256 total, uint256 lastDay, uint256 mask) = pass.getStats(carol);
        assertEq(cur + longest + total + lastDay + mask, 0, "all zero for fresh user");
    }
}
