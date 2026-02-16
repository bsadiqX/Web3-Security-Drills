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

contract DrillDexFactoryV3{

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error IdenticalAddresses();
    error ZeroAddress();
    error PoolAlreadyExists();

    /*//////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(address => mapping(address => mapping(uint24 => address))) public getPool;

    /*//////////////////////////////////////////////////////////////
                        POOL CREATION LOGIC -V3
    //////////////////////////////////////////////////////////////*/

    function createPoolV3(address tokenA, address tokenB, uint fee) external {
        // Identification as in createPair
        if (tokenA == tokenB) revert IdenticalAddresses();
        // Sorting as in createPair
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
        * - Pair constructor takes NO arguments.
        * - token0 and token1 are later set via an external initialize() function.
        * - Tokens are stored in regular storage variables.
        *
        * This allows CREATE2 deployment with constant creation bytecode,
        * because constructor arguments are not embedded in the init code.
        *
        * However, reading storage variables costs more gas than reading immutables.
        *
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
    }
}

    /*//////////////////////////////////////////////////////////////
                            DEPLOY POOL LOGIC -V3
    //////////////////////////////////////////////////////////////*/
    contract DrillDexPoolV3{

    Parameters public parameters;

    struct Parameters{
        address factory;
        address token0;
        address token1;
        uint24 fee;
        int24 tickSpacing;
    }
    function deploy(
        address factory,
        address token0,
        address token1,
        uint24 fee,
        int24 tickSpacing
    ) internal returns (address pool) {
        parameters = Parameters({factory: factory, token0: token0, token1: token1, fee: fee, tickSpacing: tickSpacing});
        pool = address(new DrillDexPoolV3{salt: keccak256(abi.encode(token0, token1, fee))}());
        delete parameters;
    }
}

    /*//////////////////////////////////////////////////////////////
                        POOL CONTRACT -V3
    //////////////////////////////////////////////////////////////*/

    // contract DrillDexPoolV3{
    // address public immutable factory;
    // address public immutable token0;
    // address public immutable token1;
    // uint24 public immutable fee;
    // int24 public immutable tickSpacing;
    // uint128 public immutable maxLiquidityPerTick;

    //  constructor() {
    //     int24 _tickSpacing;
    //     (factory, token0, token1, fee, _tickSpacing) = IUniswapV3PoolDeployer(msg.sender).parameters();
    //     tickSpacing = _tickSpacing;

    //     maxLiquidityPerTick = Tick.tickSpacingToMaxLiquidityPerTick(_tickSpacing);
    // }
    // }
