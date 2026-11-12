
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IWithdrawReceiver {
    function onWithdraw(uint256 amount) external;
}

contract CollateralVault {
    using SafeERC20 for IERC20;

    IERC20 public immutable collateralToken;
    address public engine;
    mapping(address user => uint256 amount) public collateral;

    constructor(address _collateralToken) {
        collateralToken = IERC20(_collateralToken);
    }

    function setEngine(address _engine) external {
        require(engine == address(0), "Engine already set");
        engine = _engine;
    }

    function deposit(address user, uint256 amount) external {
        require(msg.sender == engine, "Only engine");

        collateralToken.safeTransferFrom(
            user,
            address(this),
            amount
        );

        collateral[user] += amount;
    }

    function withdraw(address user, uint256 amount) external {
        require(msg.sender == engine, "Only engine");
        require(collateral[user] >= amount, "Insufficient collateral");

        /*
         * Vulnerability:
         * We call the user before reducing their recorded collateral.
         */
        if (user.code.length > 0) {
            IWithdrawReceiver(user).onWithdraw(amount);
        }

        collateral[user] -= amount;

        collateralToken.safeTransfer(user, amount);
    }
}


pragma solidity ^0.8.26;
import {CollateralVault} from "./ReentrancyCrossContract.sol";

interface IMintableERC20 {
    function mint(address to, uint256 amount) external;
}

contract StablecoinEngine {
    uint256 public constant MIN_COLLATERAL_RATIO = 150;
    uint256 public constant PRECISION = 100;

    IMintableERC20 public immutable stablecoin;
    CollateralVault public immutable vault;

    // Mock price: 1 collateral token = $1.
    uint256 public constant COLLATERAL_PRICE = 1e18;

    mapping(address user => uint256 amount) public debt;

    constructor(address _stablecoin, address _vault) {
        stablecoin = IMintableERC20(_stablecoin);
        vault = CollateralVault(_vault);
    }

    function depositCollateral(uint256 amount) external {
        vault.deposit(msg.sender, amount);
    }

    function mintStablecoin(uint256 amount) external {
        uint256 newDebt = debt[msg.sender] + amount;

        _checkCollateralRatio(
            vault.collateral(msg.sender),
            newDebt
        );

        debt[msg.sender] = newDebt;

        stablecoin.mint(msg.sender, amount);
    }

    function withdrawCollateral(uint256 amount) external {
        uint256 remainingCollateral =
            vault.collateral(msg.sender) - amount;

        _checkCollateralRatio(
            remainingCollateral,
            debt[msg.sender]
        );

        vault.withdraw(msg.sender, amount);
    }

    function _checkCollateralRatio(
        uint256 collateralAmount,
        uint256 debtAmount
    ) internal pure {
        if (debtAmount == 0) return;

        uint256 collateralValue =
            collateralAmount * COLLATERAL_PRICE / 1e18;

        uint256 ratio =
            collateralValue * PRECISION / debtAmount;

        require(
            ratio >= MIN_COLLATERAL_RATIO,
            "Undercollateralized"
        );
    }
}
