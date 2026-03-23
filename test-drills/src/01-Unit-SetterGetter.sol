// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract SetterGetter {
    uint256 public number;

    function setNumber(uint256 _number) public {
        number = _number;
    }

    function getNumber() public view returns(uint256) {
        return number;
    }
}