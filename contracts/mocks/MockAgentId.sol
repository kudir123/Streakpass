// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title MockAgentId — minimal mintable ERC-721 stub for tests
/// @notice Stands in for the SPACE ID Agent ID registry. Only the surface
///         StreakPass (and the tests) need: balanceOf, ownerOf and a free mint.
contract MockAgentId {
    string public constant name = "Mock Agent ID";
    string public constant symbol = "MAID";

    uint256 private _nextTokenId = 1;
    mapping(uint256 => address) private _owners;
    mapping(address => uint256) private _balances;

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    function mint(address to) external returns (uint256 tokenId) {
        require(to != address(0), "mint to zero address");
        tokenId = _nextTokenId++;
        _owners[tokenId] = to;
        _balances[to] += 1;
        emit Transfer(address(0), to, tokenId);
    }

    function balanceOf(address owner) external view returns (uint256) {
        require(owner != address(0), "balance of zero address");
        return _balances[owner];
    }

    function ownerOf(uint256 tokenId) external view returns (address) {
        address owner = _owners[tokenId];
        require(owner != address(0), "nonexistent token");
        return owner;
    }
}
