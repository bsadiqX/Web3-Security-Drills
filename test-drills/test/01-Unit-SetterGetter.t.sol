// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "../lib/forge-std/src/Test.sol";
import "../src/01-Unit-SetterGetter.sol";

contract SetterGetterTest is Test, SetterGetter{
    SetterGetter public setterGetter;

    function setUp() public {
        setterGetter = new SetterGetter();
    }

    function test_SetNumber() public {
        setterGetter.setNumber(41);
        setterGetter.setNumber(22);
        setterGetter.setNumber(34);
        setterGetter.setNumber(type(uint256).max);
        // setterGetter.setNumber(type(uint256).max + 1);
        // assertEq(setterGetter.getNumber(), 10);
        // assertEq(setterGetter.number(), 10);
        console2.log(address(this));
        console2.log(msg.sender);
        console2.log(setterGetter.number());
    }

    //   function test_setNumber() public {
    //     uint256 numberBefore = setterGetter.number();
    //     setterGetter.setNumber(10);
    //     uint256 numberAfter = setterGetter.number();
 
    //     assertEq(numberBefore, 0);
    //     assertEq(numberAfter, 10);
    // }
}