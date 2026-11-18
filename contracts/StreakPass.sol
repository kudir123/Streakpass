// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Minimal read interface for an ERC-721 registry (the Agent ID collection).
interface IAgentIdRegistry {
    function balanceOf(address owner) external view returns (uint256);
}

/// @title StreakPass — a daily check-in passport for Agent ID holders
/// @notice Holding an Agent ID is the access key: only wallets that hold an
///         Agent ID (checked live against the registry in `checkIn`) can check
///         in, once per UTC day, to build a streak. Reaching a streak of
///         3, 7, 14 or 30 days mints a soulbound StreakPass Badge (SPB),
///         implemented as a minimal ERC-721 inside this same contract.
///
/// @dev PERMISSIONS: NONE, BY DESIGN. This contract has no owner and no admin
///      functions of any kind: there is no privileged mint, no pause, no
///      upgrade path, no fee setting and no withdrawal. `checkIn` is
///      nonpayable and the contract never holds funds. Badges are soulbound:
///      every transfer and approval function reverts. The only way a badge
///      can ever be created is by a holder checking in on consecutive days.
contract StreakPass {
    // ------------------------------------------------------------------
    // Errors
    // ------------------------------------------------------------------
    error NoAgentId();
    error AlreadyCheckedInToday();
    error Soulbound();
    error NonexistentToken();
    error ZeroAddress();

    // ------------------------------------------------------------------
    // Events
    // ------------------------------------------------------------------
    event CheckIn(address indexed user, uint256 day, uint256 streak);
    event BadgeMinted(address indexed user, uint256 milestone, uint256 tokenId);
    /// @dev Standard ERC-721 mint event for badges (transfers never happen).
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    // ------------------------------------------------------------------
    // Badge collection metadata (minimal ERC-721, soulbound)
    // ------------------------------------------------------------------
    string public constant name = "StreakPass Badge";
    string public constant symbol = "SPB";

    /// @notice The Agent ID registry (SPACE ID Agent ID collection on BSC).
    ///         Set once at deployment and immutable: Agent ID is the key.
    IAgentIdRegistry public immutable agentIdRegistry;

    /// @notice Streak lengths (in days) that earn a badge, in ascending order.
    /// @dev Fixed at declaration and never written again after deployment.
    uint256[4] public MILESTONES = [3, 7, 14, 30];

    struct Stats {
        uint256 currentStreak;
        uint256 longestStreak;
        uint256 totalCheckIns;
        uint256 lastCheckInDay; // UTC day number: block.timestamp / 86400
        uint256 badgesMask;     // bit i set => MILESTONES[i] badge earned
    }

    mapping(address => Stats) private _stats;

    /// @notice Number of distinct users who have ever checked in.
    uint256 public totalUsers;
    /// @notice Total check-ins across all users.
    uint256 public totalCheckIns;

    // Badge storage
    uint256 private _nextTokenId = 1;
    mapping(uint256 => address) private _badgeOwner;
    mapping(uint256 => uint256) private _badgeMilestone; // tokenId => milestone days
    mapping(address => uint256) private _badgeBalance;

    constructor(address agentIdRegistry_) {
        if (agentIdRegistry_ == address(0)) revert ZeroAddress();
        agentIdRegistry = IAgentIdRegistry(agentIdRegistry_);
    }

    // ------------------------------------------------------------------
    // Core flow
    // ------------------------------------------------------------------

    /// @notice Check in for today. Requires holding an Agent ID.
    /// @dev One check-in per UTC day. A check-in on the day right after the
    ///      previous one extends the streak; any larger gap restarts the
    ///      running streak at 1 (longestStreak is preserved).
    function checkIn() external {
        if (agentIdRegistry.balanceOf(msg.sender) == 0) revert NoAgentId();

        uint256 day = block.timestamp / 86400;
        Stats storage s = _stats[msg.sender];

        if (s.totalCheckIns != 0 && s.lastCheckInDay == day) {
            revert AlreadyCheckedInToday();
        }

        bool firstEver = s.totalCheckIns == 0;

        uint256 newStreak;
        if (firstEver) {
            newStreak = 1;
        } else if (day == s.lastCheckInDay + 1) {
            newStreak = s.currentStreak + 1;
        } else {
            newStreak = 1;
        }

        s.currentStreak = newStreak;
        if (newStreak > s.longestStreak) s.longestStreak = newStreak;
        s.totalCheckIns += 1;
        s.lastCheckInDay = day;

        if (firstEver) totalUsers += 1;
        totalCheckIns += 1;

        emit CheckIn(msg.sender, day, newStreak);

        // Mint a badge the moment the streak reaches a milestone.
        for (uint256 i = 0; i < MILESTONES.length; i++) {
            uint256 milestone = MILESTONES[i];
            uint256 bit = 1 << i;
            if (newStreak == milestone && s.badgesMask & bit == 0) {
                s.badgesMask |= bit;
                _mintBadge(msg.sender, milestone);
            }
        }
    }

    function _mintBadge(address user, uint256 milestone) internal {
        uint256 tokenId = _nextTokenId++;
        _badgeOwner[tokenId] = user;
        _badgeMilestone[tokenId] = milestone;
        _badgeBalance[user] += 1;
        emit Transfer(address(0), user, tokenId);
        emit BadgeMinted(user, milestone, tokenId);
    }

    // ------------------------------------------------------------------
    // Views
    // ------------------------------------------------------------------

    /// @notice True if `user` currently holds an Agent ID.
    function hasAgentId(address user) public view returns (bool) {
        return agentIdRegistry.balanceOf(user) > 0;
    }

    /// @notice True if `user` has already checked in on the current UTC day.
    function checkedInToday(address user) public view returns (bool) {
        Stats storage s = _stats[user];
        return s.totalCheckIns != 0 && s.lastCheckInDay == block.timestamp / 86400;
    }

    /// @notice Full streak statistics for `user`.
    /// @return currentStreak Running streak in days (as of the last check-in).
    /// @return longestStreak Best streak ever reached.
    /// @return totalCheckIns_ Lifetime check-ins by this user.
    /// @return lastCheckInDay UTC day number of the last check-in (0 if never).
    /// @return badgesMask Bit i set means the MILESTONES[i] badge was earned.
    function getStats(address user)
        external
        view
        returns (
            uint256 currentStreak,
            uint256 longestStreak,
            uint256 totalCheckIns_,
            uint256 lastCheckInDay,
            uint256 badgesMask
        )
    {
        Stats storage s = _stats[user];
        return (s.currentStreak, s.longestStreak, s.totalCheckIns, s.lastCheckInDay, s.badgesMask);
    }

    // ------------------------------------------------------------------
    // Minimal ERC-721 for the badges (soulbound)
    // ------------------------------------------------------------------

    function balanceOf(address owner) external view returns (uint256) {
        if (owner == address(0)) revert ZeroAddress();
        return _badgeBalance[owner];
    }

    function ownerOf(uint256 tokenId) public view returns (address) {
        address owner = _badgeOwner[tokenId];
        if (owner == address(0)) revert NonexistentToken();
        return owner;
    }

    function tokenURI(uint256 tokenId) external view returns (string memory) {
        if (_badgeOwner[tokenId] == address(0)) revert NonexistentToken();
        uint256 milestone = _badgeMilestone[tokenId];
        string memory svg = _badgeSvg(milestone);
        string memory json = string.concat(
            '{"name":"StreakPass Badge - ',
            _toString(milestone),
            '-Day Streak","description":"Soulbound badge awarded by StreakPass for a ',
            _toString(milestone),
            '-day check-in streak. Non-transferable by design.","image":"data:image/svg+xml;base64,',
            _base64Encode(bytes(svg)),
            '","attributes":[{"trait_type":"Milestone","value":"',
            _toString(milestone),
            '-Day Streak"},{"trait_type":"Transferable","value":"No (soulbound)"}]}'
        );
        return string.concat("data:application/json;base64,", _base64Encode(bytes(json)));
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == 0x01ffc9a7 // ERC-165
            || interfaceId == 0x80ac58cd // ERC-721
            || interfaceId == 0x5b5e139f; // ERC-721 metadata
    }

    // --- Soulbound: every transfer / approval path reverts, always. ---

    function transferFrom(address, address, uint256) external pure {
        revert Soulbound();
    }

    function safeTransferFrom(address, address, uint256) external pure {
        revert Soulbound();
    }

    function safeTransferFrom(address, address, uint256, bytes calldata) external pure {
        revert Soulbound();
    }

    function approve(address, uint256) external pure {
        revert Soulbound();
    }

    function setApprovalForAll(address, bool) external pure {
        revert Soulbound();
    }

    function getApproved(uint256 tokenId) external view returns (address) {
        if (_badgeOwner[tokenId] == address(0)) revert NonexistentToken();
        return address(0); // soulbound: approvals can never exist
    }

    function isApprovedForAll(address, address) external pure returns (bool) {
        return false;
    }

    // ------------------------------------------------------------------
    // Badge artwork (inline SVG, one per milestone)
    // ------------------------------------------------------------------

    function _badgeSvg(uint256 milestone) internal pure returns (string memory) {
        string memory color;
        string memory label;
        if (milestone == 3) {
            color = "#cd7f32";
            label = "BRONZE";
        } else if (milestone == 7) {
            color = "#b8c4ce";
            label = "SILVER";
        } else if (milestone == 14) {
            color = "#f5b921";
            label = "GOLD";
        } else {
            color = "#59d7ff";
            label = "DIAMOND";
        }
        return string.concat(
            '<svg xmlns="http://www.w3.org/2000/svg" width="400" height="400" viewBox="0 0 400 400">',
            '<rect width="400" height="400" fill="#0e1526"/>',
            '<circle cx="200" cy="168" r="104" fill="none" stroke="',
            color,
            '" stroke-width="10"/>',
            '<text x="200" y="158" font-family="Arial,sans-serif" font-size="84" font-weight="bold" fill="',
            color,
            '" text-anchor="middle">',
            _toString(milestone),
            '</text>',
            '<text x="200" y="206" font-family="Arial,sans-serif" font-size="26" fill="#ffffff" text-anchor="middle">DAY STREAK</text>',
            '<text x="200" y="316" font-family="Arial,sans-serif" font-size="30" font-weight="bold" fill="#ffffff" text-anchor="middle">STREAKPASS</text>',
            '<text x="200" y="350" font-family="Arial,sans-serif" font-size="20" fill="',
            color,
            '" text-anchor="middle">',
            label,
            ' BADGE</text>',
            "</svg>"
        );
    }

    // ------------------------------------------------------------------
    // Small helpers
    // ------------------------------------------------------------------

    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10))); // forge-lint: disable-line(unsafe-typecast) -- value is 48..57, always fits
            value /= 10;
        }
        return string(buffer);
    }

    function _base64Encode(bytes memory data) internal pure returns (string memory) {
        bytes memory table = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
        if (data.length == 0) return "";
        uint256 encodedLength = 4 * ((data.length + 2) / 3);
        bytes memory result = new bytes(encodedLength);
        uint256 j = 0;
        for (uint256 i = 0; i < data.length; i += 3) {
            uint256 a = uint8(data[i]);
            uint256 b = i + 1 < data.length ? uint8(data[i + 1]) : 0;
            uint256 c = i + 2 < data.length ? uint8(data[i + 2]) : 0;
            uint256 triple = (a << 16) | (b << 8) | c;
            result[j++] = table[(triple >> 18) & 0x3F];
            result[j++] = table[(triple >> 12) & 0x3F];
            result[j++] = table[(triple >> 6) & 0x3F];
            result[j++] = table[triple & 0x3F];
        }
        uint256 mod = data.length % 3;
        if (mod == 1) {
            result[encodedLength - 1] = "=";
            result[encodedLength - 2] = "=";
        } else if (mod == 2) {
            result[encodedLength - 1] = "=";
        }
        return string(result);
    }
}
