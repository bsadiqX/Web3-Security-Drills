// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * A minimal contract used to demonstrate how `delegatecall`
 * alters execution context while reusing bytecode.
 *
 * This contract assumes:
 * - It controls its own storage layout.
 * - It executes within its own deployment context.
 *
 * When executed via `delegatecall`, these assumptions break.
 *
 * Storage Layout:
 * ┌───────────────┬────────────┐
 * │ Slot          │ Variable   │
 * ├───────────────┼────────────┤
 * │ 0             │ value      │
 * │ 1             │ lastSender │
 * │ 2             │ self       │
 * └───────────────┴────────────┘
 */
contract BasicLogic {
    /// @notice Arbitrary stored value (slot 0)
    uint256 public value;

    /// @notice Records msg.sender observed during execution (slot 1)
    address public lastSender;

    /// @notice Records address(this) observed during execution (slot 2)
    address public self;

    /**
     * @notice Stores a value and records execution context.
     * @param _value Value to store.
     *
     * @dev
     * Observations:
     * - Under normal call:
     *      address(this) = BasicLogic
     * - Under delegatecall:
     *      address(this) = caller contract
     *
     * msg.sender is preserved across delegatecall.
     */
    function setValue(uint256 _value) external {
        value = _value;
        lastSender = msg.sender;
        self = address(this);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * Executes external contract logic via delegatecall.
 *
 * Storage layout intentionally mirrors BasicLogic.
 * This ensures clean observation of storage mutation.
 *
 * Storage Layout:
 * ┌───────────────┬────────────┐
 * │ Slot          │ Variable   │
 * ├───────────────┼────────────┤
 * │ 0             │ value      │
 * │ 1             │ lastSender │
 * │ 2             │ self       │
 * └───────────────┴────────────┘
 *
 * Demonstrates execution-context hijacking.
 */
contract DelegateCaller {
    uint256 public value;
    address public lastSender;
    address public self;

    /**
     * @notice Executes target logic in this contract's storage context.
     * @param target Address containing logic.
     * @param _value Value to pass to setValue().
     */
    function delegateSet(address target, uint256 _value) external {
        (bool success,) = target.delegatecall(
            abi.encodeWithSignature("setValue(uint256)", _value)
        );

        require(success, "DELEGATE_FAILED");
    }
}