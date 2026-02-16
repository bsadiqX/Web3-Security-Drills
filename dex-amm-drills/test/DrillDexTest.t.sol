// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "../../lib/forge-std/src/Test.sol";
import "../src/101-CreatePairV2.sol";

/// @notice Mock ERC20 token used for DEX drills
contract MockERC20 {
    string public name;
    string public symbol;
    uint8 public decimals = 18;

    constructor(string memory _n, string memory _s) {
        name = _n;
        symbol = _s;
    }
}

/// @notice Security drill tests for DrillDexFactory / DrillDexPair
contract DrillDexFactoryTest is Test {
    DrillDexFactory factory;

    address tokenA;
    address tokenB;
    address tokenC;
    address tokenD;

    address attacker = address(0xBEEF);

    function setUp() public {
        factory = new DrillDexFactory();

        tokenA = address(new MockERC20("TokenA", "A"));
        tokenB = address(new MockERC20("TokenB", "B"));
        tokenC = address(new MockERC20("TokenC", "C"));
        tokenD = address(new MockERC20("TokenD", "D"));
    }

    /*//////////////////////////////////////////////////////////////
                            HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns token addresses in canonical order (token0 < token1)
    function sortTokens(address a, address b)
        internal
        pure
        returns (address token0, address token1)
    {
        (token0, token1) = a < b ? (a, b) : (b, a);
    }

    /// @notice Computes the deterministic CREATE2 address for a pair
    function computePairAddress(
        address factoryAddr,
        address token0,
        address token1
    ) internal pure returns (address) {
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        bytes32 bytecodeHash = keccak256(type(DrillDexPair).creationCode);

        return address(uint160(uint(keccak256(abi.encodePacked(
            hex"ff",         // CREATE2 prefix
            factoryAddr,     // Factory address as deployer
            salt,            // Salt derived from token pair
            bytecodeHash     // Hash of pair contract creation code
        )))));
    }

    /*//////////////////////////////////////////////////////////////
                        FACTORY INVARIANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test that creating a pair with identical tokens reverts
    function test_sameToken_reverts() public {
        vm.expectRevert(DrillDexFactory.IdenticalAddresses.selector);
        factory.createPair(tokenA, tokenA);
    }

    /// @notice Test that zero address inputs are rejected
    function test_zeroAddress_reverts() public {
        vm.expectRevert(DrillDexFactory.ZeroAddress.selector);
        factory.createPair(address(0), tokenA);

        vm.expectRevert(DrillDexFactory.ZeroAddress.selector);
        factory.createPair(tokenA, address(0));

        vm.expectRevert(DrillDexFactory.IdenticalAddresses.selector);
        factory.createPair(address(0), address(0));
    }

    /// @notice Check that getPair is symmetric: getPair[a][b] == getPair[b][a]
    function test_ordering_symmetry() public {
        address pair1 = factory.createPair(tokenA, tokenB);
        address pair2 = factory.getPair(tokenB, tokenA);

        assertEq(pair1, pair2);
    }

    /// @notice Creating the same pair twice should revert
    function test_duplicatePair_reverts() public {
        factory.createPair(tokenA, tokenB);

        vm.expectRevert(DrillDexFactory.PairAlreadyExists.selector);
        factory.createPair(tokenA, tokenB);

        vm.expectRevert(DrillDexFactory.PairAlreadyExists.selector);
        factory.createPair(tokenB, tokenA);
    }

        /*//////////////////////////////////////////////////////////////
                        CREATE2 DETERMINISM
    //////////////////////////////////////////////////////////////*/

    /// @notice Test that CREATE2 address is deterministic and matches expected
    /// @dev Includes an inline example showing salt, bytecode hash, and computed address
    function test_create2_address_deterministic() public {
        (address t0, address t1) = sortTokens(tokenA, tokenB);

        // Step 1: Compute CREATE2 salt
        bytes32 salt = keccak256(abi.encodePacked(t0, t1));

        // Step 2: Compute bytecode hash of the pair contract
        bytes32 bytecodeHash = keccak256(type(DrillDexPair).creationCode);

        // Step 3: Compute expected CREATE2 address manually
        address expected = address(uint160(uint(keccak256(abi.encodePacked(
            hex"ff",        // CREATE2 prefix
            address(factory), // Deployer (factory)
            salt,           // Deterministic salt
            bytecodeHash    // Hash of creation code
        )))));

        // Step 4: Deploy the pair using factory
        address actual = factory.createPair(tokenA, tokenB);

        // Inline example: log intermediate values for clarity
        emit log_named_bytes32("Salt (keccak256(token0, token1))", salt);
        emit log_named_bytes32("Bytecode hash", bytecodeHash);
        emit log_named_address("Expected CREATE2 address", expected);
        emit log_named_address("Actual deployed address", actual);

        // Final check: expected address matches actual
        assertEq(actual, expected);
    }

    /*//////////////////////////////////////////////////////////////
                        PAIR INITIALIZATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Test that pair tokens are set correctly on initialization
    function test_pair_initialized_correctly() public {
        address pair = factory.createPair(tokenA, tokenB);
        DrillDexPair p = DrillDexPair(pair);

        (address t0, address t1) = sortTokens(tokenA, tokenB);

        assertEq(p.token0(), t0);
        assertEq(p.token1(), t1);
    }

    /*//////////////////////////////////////////////////////////////
                🔥 INTENTIONAL VULNERABILITY TEST
    //////////////////////////////////////////////////////////////*/

    /// @notice Demonstrates what happens if initialization is not restricted
    function test_pair_canBeReinitialized_byAnyone() public {
        address pair = factory.createPair(tokenA, tokenB);

        vm.prank(attacker);
        DrillDexPair(pair).initialize(attacker, attacker);

        assertEq(DrillDexPair(pair).token0(), attacker);
        assertEq(DrillDexPair(pair).token1(), attacker);
    }

    /*//////////////////////////////////////////////////////////////
                        SYSTEM INTEGRITY
    //////////////////////////////////////////////////////////////*/

    /// @notice Check that allPairs array tracks deployed pairs
    function test_allPairs_tracking() public {
        address p1 = factory.createPair(tokenA, tokenB);
        address p2 = factory.createPair(tokenC, tokenD);

        assertEq(factory.allPairs(0), p1);
        assertEq(factory.allPairs(1), p2);
    }

    /// @notice Check that deployed pair has runtime bytecode
    function test_pair_hasRuntimeCode() public {
        address pair = factory.createPair(tokenA, tokenB);
        assertGt(pair.code.length, 0);
    }
}