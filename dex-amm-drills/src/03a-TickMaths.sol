// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * Key limitations of Uniswap V2 stemming from its lack of a tick-based system (which was
 * introduced in V3):
 * 
 * Capital Inefficiency:
 * Liquidity is spread uniformly across the entire price range (0 to ∞), meaning the 
 * vast majority of liquidity sits unused at prices far from the current market price.
 * This makes it extremely capital inefficient compared to concentrated liquidity.
 * 
 * No Concentrated Liquidity
 * LPs cannot target a specific price range where they expect trading to occur. In V3,
 * ticks define discrete price boundaries that allow LPs to concentrate capital where
 * it's most useful, earning more fees per asset deposited. 
 * 
 * Lower Fee Earnings for LPs:
 * Because liquidity is diluted across all prices, LPs earn proportionally less in fees
 * compared to V3 LPs who concentrate liquidity around the active price. A V3 LP providing
 * the same capital in a tight range can earn significantly more.
 * 
 * No Multiple Fee Tiers:
 * V2 uses a flat 0.3% fee for all pairs. Without a tick system, there's no infrastructure
 * to support multiple fee tiers (e.g., 0.05%, 0.3%, 1%), which means it can't efficiently
 * serve both stable and volatile asset pairs.
 * 
 * Higher Slippage for Large Trades:
 * With liquidity spread thin, large trades experience more slippage because there isn't
 * enough depth concentrated around the current price to absorb them efficiently. Less
 * Competitive for Professional Market Makers, The uniform distribution model doesn't allow
 * sophisticated LPs to implement active market-making strategies, making it less attractive
 * for professionals who want fine-grained control over their positions.
 */