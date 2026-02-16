// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title DEX / AMM Security Drill
 * @author bsadiq
 *
 * This contract is NOT intended to be a production-ready DEX.
 * It exists as a controlled research environment for analyzing how
 * AMM-based protocols are designed, structured, and secured.
 * 
 * All implementations are written from first principles after studying
 * publicly available protocol designs and documentation.
 *
 * This contract is intended for security research, reverse engineering,
 * and deep protocol analysis — not deployment.
 */

contract DrillDexFactory {

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error IdenticalAddresses();
    error ZeroAddress();
    error PairAlreadyExists();

    /*//////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event PairCreated(
        address indexed token0,
        address indexed token1,
        address pair,
        uint256 index
    );

    /*//////////////////////////////////////////////////////////////
                           PAIR CREATION LOGIC -V2
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deploys a new pair contract for two ERC20 tokens.
     *
     * @dev
     * Key concepts drilled here:
     * - Token address sorting (canonical ordering)
     * - CREATE2-based deterministic deployment
     * - Factory-controlled initialization
     *
     * Important assumptions:
     * - tokenA and tokenB are ERC20-compatible
     * - No validation of token behavior is performed
     *
     * @param tokenA First token address (unordered)
     * @param tokenB Second token address (unordered)
     *
     * @return pair Address of the newly created pair contract
     */
    function createPair(
        address tokenA,
        address tokenB
    ) external returns (address pair) {

        // Prevent creation of a pair with identical token addresses
        if (tokenA == tokenB) revert IdenticalAddresses();

        /**
         * Canonical token ordering.
         *
         * Why this matters:
         * - Ensures (tokenA, tokenB) and (tokenB, tokenA)
         *   always resolve to the SAME pair
         * - Prevents duplicate pools for the same asset pair
         *
         * Convention:
         * token0 = lower address
         * token1 = higher address
         */
        (address token0, address token1) =
            tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);

        // Zero address check (only token0 needs to be checked after sorting)
        // because if both are zero addresses it would've reverted earlier "IdenticalAddresses()",
        // zero address is lowest, and during ordering it is always ordered as token0.
        if (token0 == address(0)) revert ZeroAddress();

        // Ensure the pair does not already exist
        if (getPair[token0][token1] != address(0))
            revert PairAlreadyExists();

        /**
         * Fetch the creation bytecode of the pair contract.
         *
         * Note:
         * - This bytecode does NOT include constructor arguments
         * - Initialization is performed in a separate step
         */
        bytes memory bytecode = type(DrillDexPair).creationCode;

        /**
         * CREATE2 salt.
         *
         * Using (token0, token1) guarantees:
         * - Deterministic pair address
         * - One unique pool per token pair
         *
         * Address formula:
         * keccak256(0xff ++ factory ++ salt ++ keccak256(bytecode))
         */
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));

        // Deploy the pair contract using CREATE2
        assembly {
            pair := create2(
                0,                      // no ETH sent
                add(bytecode, 32),      // skip length prefix
                mload(bytecode),        // bytecode length
                salt                    // deterministic salt
            )
        }

        /**
         * Initialize the newly deployed pair.
         *
         * Why initialization is external:
         * - CREATE2 cannot pass constructor arguments easily
         * - Mirrors Uniswap V2 architecture
         *
         * SECURITY NOTE:
         * Initialization MUST be restricted in the pair contract.
         */
        DrillDexPair(pair).initialize(token0, token1);

        // Store pair address for both token orderings
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair;

        allPairs.push(pair);

        emit PairCreated(token0, token1, pair, allPairs.length);
    }
}

/*//////////////////////////////////////////////////////////////
                        PAIR CONTRACT
//////////////////////////////////////////////////////////////*/

contract DrillDexPair {
    address public immutable factory;
    address public token0;
    address public token1;

    error Forbidden();
    error AlreadyInitialized();

    constructor() {
        // Factory is the deployer (DrillDexFactory)
        factory = msg.sender;
    }

    /**
     * @notice Initializes the pair with token addresses.
     *
     * @dev
     * SECURITY CRITICAL:
     * - Can only be called once
     * - Can only be called by the factory
     *
     * This prevents:
     * - Re-initialization attacks
     * - Token address overwrite
     */
    function initialize(address _token0, address _token1) external {
        if (msg.sender != factory) revert Forbidden();
        if (token0 != address(0) || token1 != address(0)) revert AlreadyInitialized();

        token0 = _token0;
        token1 = _token1;
    }
}