// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "../lib/forge-std/src/Test.sol";
import "../src/101-DelegateWhoAmI.sol";

/**
 * TEST OBJECTIVE:
 * - Prove that normal call returns logic address
 * - Prove that delegatecall returns caller address
 */
contract WhoAmIContextTest is Test {

    WhoAmILogic logic;
    WhoAmICaller caller;

    function setUp() public {
        logic = new WhoAmILogic();
        caller = new WhoAmICaller();
    }

    function test_NormalCall_ReturnsLogicAddress() public {
        address result = caller.callWhoAmI(address(logic));

        assertEq(
            result,
            address(logic),
            "Normal call should return logic address"
        );
    }

    function test_DelegateCall_ReturnsCallerAddress() public {
        address result = caller.delegateWhoAmI(address(logic));

        assertEq(
            result,
            address(caller),
            "Delegatecall should return caller address"
        );
    }
}