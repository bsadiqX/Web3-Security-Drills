// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TreasuryVault {

    address public owner;
    address public pendingOwner;

    struct Grant {
        uint256 amount;
        uint256 unlockedAt;
        bool claimed;
    }

    mapping(address => Grant) public grants;
    mapping(address => bool) public whitelist;

    ERC20 public token;

    constructor(address _token) {
        owner = msg.sender;
        token = ERC20(_token);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    // ── Ownership transfer (two-step) ──────────────────────────────────────

    /// @notice Step 1 — owner nominates a new owner
    function transferOwnership(address newOwner) external onlyOwner {
        pendingOwner = newOwner;
    }

    /// @notice Step 2 — pending owner accepts
    function acceptOwnership() external {
        owner = msg.sender;
        pendingOwner = address(0);
    }

    // ── Whitelist ──────────────────────────────────────────────────────────

    /// @notice Owner adds addresses to whitelist
    function addToWhitelist(address account) external onlyOwner {
        whitelist[account] = true;
    }

    /// @notice Owner removes addresses from whitelist
    function removeFromWhitelist(address account) external onlyOwner {
        whitelist[account] = false;
    }

    // ── Grants ─────────────────────────────────────────────────────────────

    /// @notice Owner creates a vesting grant for a whitelisted address
    function createGrant(address recipient, uint256 amount, uint256 unlockDelay) external onlyOwner {
        require(whitelist[recipient], "Not whitelisted");
        require(grants[recipient].amount == 0, "Grant exists");

        grants[recipient] = Grant({
            amount: amount,
            unlockedAt: block.timestamp + unlockDelay,
            claimed: false
        });

        token.transferFrom(msg.sender, address(this), amount);
    }

    /// @notice Whitelisted recipient claims their unlocked grant
    function claimGrant() external {
        require(whitelist[msg.sender], "Not whitelisted");
        Grant storage g = grants[msg.sender];
        require(g.amount > 0, "No grant");
        require(!g.claimed, "Already claimed");
        require(block.timestamp >= g.unlockedAt, "Still locked");

        g.claimed = true;
        token.transfer(msg.sender, g.amount);
    }

    // ── Emergency ──────────────────────────────────────────────────────────

    /// @notice Owner can sweep all tokens in emergency
    function emergencySweep(address to) external onlyOwner {
        token.transfer(to, token.balanceOf(address(this)));
    }
}