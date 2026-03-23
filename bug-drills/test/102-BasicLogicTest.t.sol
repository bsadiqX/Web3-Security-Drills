// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../src/102-DelegateBasicLogic.sol";

/**
 * Validates execution context differences between
 * normal call and delegatecall.
 */
contract DelegateContextTest is Test {

    function testDelegateExecutionContext() public {
        BasicLogic logic = new BasicLogic();
        DelegateCaller caller = new DelegateCaller();

        caller.delegateSet(address(logic), 123);

        // Victim storage untouched
        assertEq(logic.value(), 0);

        // Caller storage mutated
        assertEq(caller.value(), 123);

        // msg.sender preserved (test contract)
        assertEq(caller.lastSender(), address(this));

        // address(this) observed inside delegatecall
        assertEq(caller.self(), address(caller));
    }
}