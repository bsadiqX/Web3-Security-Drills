// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * Minimal contract to demonstrate how `address(this)`
 * behaves differently under `call` vs `delegatecall`.
 *
 * @dev
 * - Normally, `address(this)` points to the contract being called.
 * - Under `delegatecall`, the code is executed in the **context of the caller**.
 * - This breaks any assumption that `address(this)` is the logic contract itself.
 */
contract WhoAmILogic {

    /**
     * @notice Returns the current contract context (`address(this)`).
     *
     * - When called normally, returns the address of WhoAmILogic.
     * - When called via `delegatecall`, returns the address of the caller contract.
     * - Shows why relying on `address(this)` for auth or vault logic is dangerous.
     */
    function whoAmI() external view returns (address) {
        return address(this);
    }
}

/**
 * @notice Contract to demonstrate differences between `call`/`staticcall` and `delegatecall`.
 *
 * - Shows why decoding return data from delegatecall requires special attention.
 */
contract WhoAmICaller {

    /**
     * @notice Calls `whoAmI()` via normal call (staticcall) and returns the address.
     *
     * @dev
     * - Normal call preserves the logic contract's context.
     * - Safe to decode inline in the return statement:
     *   `return abi.decode(data, (address));`
     *
     * @param logic Address of WhoAmILogic.
     * @return The `address(this)` from the logic contract's perspective.
     */
    function callWhoAmI(address logic) external view returns (address) {
        (bool success, bytes memory data) =
            logic.staticcall(abi.encodeWithSignature("whoAmI()"));
        require(success, "call failed");
        return abi.decode(data, (address));
    }

    /**
     * @notice Calls `whoAmI()` via delegatecall and returns the address.
     *
     * @dev
     * Delegatecall key points:
     * 1. Executes code of `logic` but in the context of `WhoAmICaller`.
     * 2. `address(this)` now equals the caller contract, not the logic contract.
     * 3. `delegatecall` can modify storage, so function cannot be `view`.
     * 4. Returned data is raw `bytes`, must be decoded.

     * Why we use a **local variable (`result`)**:
     * - Direct inline decoding like `return abi.decode(data, (address));` can fail
     *   in non-view or storage-modifying contexts due to how the EVM handles memory.
     * - Using a local variable:
     *   a. Allocates memory explicitly for decoding.
     *   b. Avoids stack/memory corruption issues.
     *   c. Makes the execution path clear — very important when demonstrating
     *      delegatecall vulnerabilities.
     * - Shows best practice for safe decoding when using delegatecall in drills
     *   or real-world protocols.
     *
     * SECURITY LESSON:
     * - Any contract relying on `address(this)` for authentication or internal checks
     *   can be exploited via delegatecall if the check assumes its own address.
     *
     * @param logic Address of the contract containing `whoAmI()`.
     * @return result The `address(this)` observed from the caller's context.
     */
    function delegateWhoAmI(address logic) external returns (address result) {
        (bool success, bytes memory data) =
            logic.delegatecall(abi.encodeWithSignature("whoAmI()"));
        require(success, "delegatecall failed");

        // Decode into local variable for clarity and memory safety
        result = abi.decode(data, (address));
    }
}