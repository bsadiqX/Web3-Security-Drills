// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "../lib/forge-std/src/Test.sol";
import "../src/02-Mocking.sol";

contract MockingTest is Test{
    Vault vault;
    address tokenA = makeAddr("TokenA");

    function setUp() external {
        vault = new Vault(tokenA);
    }

    function test_deposit() external {
        vm.mockCall(
            tokenA,
            abi.encodeWithSelector(
                IERC20.transferFrom.selector,
                    address(this),
                    address(vault),
                    10
            ),
            abi.encode(true)
        );
        vault.deposit(10);
        assertEq(vault.balances(address(this)), 10);
    }

    function test_reverts_if_false() external {
        vm.mockCall(
            tokenA,
            abi.encodeWithSelector,
        )
    }
}

















































// pragma solidity ^0.8.30;

// import "../lib/forge-std/src/Test.sol";
// import "../src/02-Mocking.sol";

// contract MockingTest is Test {

//     Vault vault;

//     address tokenA = makeAddr("TokenA");

//     function setUp() public {
//         vault = new Vault(tokenA);
//     }

//     function test_deposit_success() external {
//         vm.mockCall(
//             tokenA,
//             abi.encodeWithSelector(
//                 IERC20.transferFrom.selector,
//                 address(this),
//                 address(vault),
//                 10
//             ),
//             abi.encode(true)
//         );
//         vault.deposit(10);
//         assertEq(vault.balances(address(this)), 10);
//     }

//     function test_transfer_returns_false_reverts() external {

//         vm.mockCall(
//             tokenA,
//             abi.encodeWithSelector(
//                 IERC20.transferFrom.selector,
//                 address(this),
//                 address(vault),
//                 10
//             ),
//             abi.encode(false)
//         );
//         vm.expectRevert("Transfer failed");
//         vault.deposit(10);
//     }
// }