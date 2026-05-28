// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract AirdropDistributor {
    using ECDSA for bytes32;

    /// @dev typehash identifies the Claim struct schema for hashing
    bytes32 public constant CLAIM_TYPEHASH = keccak256(
        "Claim(address recipient,uint256 amount)"
    );

    /// @dev the trusted backend key that signs claim authorizations
    address public signer;

    /// @dev deployer, can update signer and withdraw remaining tokens
    address public owner;

    /// @dev the ERC20 token being distributed in this airdrop
    IERC20 public token;

    /// @dev tracks whether an address has already claimed
    mapping(address => bool) public hasClaimed;

    constructor(address _token, address _signer) {
        token = IERC20(_token);
        signer = _signer;
        owner = msg.sender;
    }

    /// @dev called by recipient to claim their airdrop allocation
    /// @param amount the amount of tokens the signer authorized for this recipient
    /// @param signature the backend signature authorizing this claim
    function claim(uint256 amount, bytes memory signature) external {
        /// @dev prevents same address claiming twice
        require(!hasClaimed[msg.sender], "Already claimed");

        /// @dev manually builds EIP191 digest
        /// encodes typehash + recipient + amount, then prepends \x19\x01
        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            keccak256(abi.encode(CLAIM_TYPEHASH, msg.sender, amount))
        ));

        /// @dev recovers the signer from digest + signature
        /// if recovered address matches trusted signer, claim is authorized
        address recovered = digest.recover(signature);
        require(recovered == signer, "Invalid signature");

        /// @dev marks claimed before transfer to prevent reentrancy
        hasClaimed[msg.sender] = true;

        /// @dev transfers authorized amount to recipient
        token.transfer(msg.sender, amount);
    }

    /// @dev owner can rotate the signer key
    function updateSigner(address newSigner) external {
        require(msg.sender == owner, "Not owner");
        signer = newSigner;
    }

    /// @dev owner sweeps unclaimed tokens after airdrop ends
    function withdrawRemaining(address to) external {
        require(msg.sender == owner, "Not owner");
        token.transfer(to, token.balanceOf(address(this)));
    }
}