// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "../lib/v3-core/contracts/UniswapV3Pool.sol";
import "../lib/v3-core/contracts/UniswapV3PoolDeployer.sol";
import '../lib/v3-core/contracts/NoDelegateCall.sol';
/**
 * @notice This contract demonstrates step-by-step how a Uniswap V3 pool is created.
 *         Designed for educational purposes, similar to a CreatePairV2.
 */

contract FactoryV3 is UniswapV3PoolDeployer, NoDelegateCall{

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error IdenticalAddresses();
    error ZeroAddress();
    error PoolAlreadyExists();

    /*//////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/

    address public owner;
    mapping(address => mapping(address => mapping(uint24 => address))) public getPool;
    mapping(uint24 => int24) public feeAmountTickSpacing; // tick spacing per fee tier

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() {
        owner = msg.sender;

        // Standard V3 fee tiers and their tick spacing
        feeAmountTickSpacing[500] = 10;      // 0.05%
        feeAmountTickSpacing[3000] = 60;     // 0.3%
        feeAmountTickSpacing[10000] = 200;   // 1%
    }

    /*//////////////////////////////////////////////////////////////
                        POOL CREATION LOGIC -V3
    //////////////////////////////////////////////////////////////*/

    function createPoolV3(address tokenA, address tokenB, uint24 fee) external noDelegateCall returns (address pool) {

        // Prevents identical token addresses.
        if (tokenA == tokenB) revert IdenticalAddresses();
        // Sort token addresses.
        (address token0, address token1) =
            tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        // Zero address check!
        if (token0 == address(0)) revert ZeroAddress();
        // Pool existance check!
        if (getPool[token0][token1][fee] != address(0))
            revert PoolAlreadyExists();
        /**
        * @notice Explains why Uniswap V3 uses a separate PoolDeployer contract
        *         instead of directly deploying pools with constructor arguments.
        *
        * @dev Architectural Comparison: Uniswap V2 vs Uniswap V3
        *
        * --- Uniswap V2 Pattern ---
        *
        * - The pair contract constructor takes NO arguments.
        * - token0 and token1 are later set via an external `initialize()` function.
        * - Tokens are stored in regular storage variables.
        * - CREATE2 deployment can only be deterministic if the init code is constant,
        *   which is easy here since no constructor args are embedded.
        *
        * --- Uniswap V3 Pattern ---
        *
        * - token0, token1, fee, and tickSpacing are declared as immutable.
        * - Immutable variables MUST be assigned inside the constructor.
        * - Immutable reads are cheaper than storage reads.
        *
        * Problem:
        * If constructor arguments were passed normally, they would become part of
        * the contract's creation bytecode.
        *
        * CREATE2 address formula:
        *
        *   address = keccak256(
        *       0xff,
        *       deployer,
        *       salt,
        *       keccak256(init_code)
        *   )
        *
        * Since init_code includes constructor arguments,
        * passing arguments directly would change the init_code hash
        * for every different pool configuration.
        *
        *
        * --- Why the Deployer Pattern Exists ---
        *
        * To keep the pool's init_code constant across all deployments:
        *
        * 1. The deployer temporarily stores pool parameters in storage.
        * 2. The pool is deployed with an empty constructor signature.
        * 3. The pool constructor reads parameters from msg.sender (the deployer).
        * 4. The deployer deletes the parameters after deployment.
        *
        * This allows:
        *
        * - Deterministic CREATE2 addresses
        * - Constant creation bytecode hash
        * - Immutable configuration
        * - Gas-efficient parameter access
        *
        *
        * --- Why V3 Does NOT Use initialize() Like V2 ---
        *
        * Using initialize() would require storing parameters in storage,
        * increasing gas costs on every swap.
        *
        * V3 prioritizes:
        * - Gas efficiency
        * - Immutability guarantees
        * - Deterministic pool address computation
        *
        * Therefore, the deployer + transient storage pattern
        * is a deliberate architectural optimization.
        */
       pool = deploy(address(this), token0, token1, fee, tickSpacing);
       getPool[token0][token1][fee] = pool;
       getPool[token1][token0][fee] = pool;
       emit PoolCreated(token0, token1, fee, tickSpacing, pool);
    }

    /*
    * =============================
    * NOTE:
    * =============================
    * In Uniswap V3, deployment and price initialization are separated.
    *
    * DIFFERENCE FROM UNISWAP V2:
    * - Uniswap V2 also has an `initialize()` function,
    *   but V2's initialize() only sets token0 and token1.
    * - In V2, price is NOT initialized here.
    * - Price in V2 is implicitly defined later by the first liquidity deposit
    *   via the ratio of token0/token1 provided.
    *
    * In contrast:
    * - V3 requires price to be explicitly initialized BEFORE liquidity can be added.
    *
    * WHY V3 REQUIRES EXPLICIT PRICE:
    * - V3 uses concentrated liquidity.
    * - Liquidity exists within discrete tick ranges.
    * - Active liquidity depends on knowing the current tick.
    * - Therefore, a starting price must be defined first.
    *
    * param sqrtPriceX96 The initial sqrt(token1/token0) price as Q64.96.
    * Example:
    *     If price = 2000,
    *     sqrtPriceX96 = sqrt(2000) * 2^96.
    *
    * REQUIREMENTS:
    * - Pool must not already be initialized.
    * - sqrtPriceX96 must be within TickMath bounds.
    * 
    * // function initialize(uint160 sqrtPriceX96) external {
    *
    * DIFFERENCE FROM V2:
    * - V2 initialize() only sets token addresses, thus it checks only whether they exists.
    * - V2 economic state (reserves, price) is established later
    *   during the first liquidity mint.
    *
    * In V3, economic state begins here.
    * 
    * // require(slot0.sqrtPriceX96 == 0, 'AI');
    *
    * Converts continuous sqrt price into discrete tick.
    *
    * DIFFERENCE FROM V2:
    * - V2 does not use ticks or logarithmic price representation.
    * - V2 price is derived directly from reserves.
    *
    * V3 requires ticks because:
    * - Liquidity is distributed across discrete price intervals.
    * - Swap logic operates by crossing ticks.
    *
    * We derive tick internally to ensure:
    * - sqrtPrice and tick remain mathematically consistent.
    * - Caller cannot provide inconsistent values.
    * // int24 tick = TickMath.getTickAtSqrtRatio(sqrtPriceX96);
    *
    * Initializes oracle observation storage.
    *
    * DIFFERENCE FROM V2:
    * - V2 stores cumulative price variables directly in the pair contract.
    * - V3 uses a ring buffer of observations with configurable cardinality.
    *
    * Oracle storage must be initialized before swaps occur.
    * // (uint16 cardinality, uint16 cardinalityNext) =
    * // observations.initialize(_blockTimestamp());
    *
    * Writes all core state variables into slot0.
    *
    * DIFFERENCE FROM V2:
    * - V2 core state is reserve-based.
    * - V3 core state is price-and-tick based.
    *
    * V3 stores sqrtPrice directly because liquidity is virtual
    * and range-based rather than uniformly distributed.
    *
    * unlocked:
    * - Enables the reentrancy guard for future operations.
    * - No lock needed during initialize because:
    *     • No token transfers occur
    *     • No external calls occur
    *     • No liquidity exists yet
    * // slot0 = Slot0({
    * // sqrtPriceX96: sqrtPriceX96,
    * // tick: tick,
    * // observationIndex: 0,
    * // observationCardinality: cardinality,
    * // observationCardinalityNext: cardinalityNext,
    * // feeProtocol: 0,
    * // unlocked: true
    * // });
    */