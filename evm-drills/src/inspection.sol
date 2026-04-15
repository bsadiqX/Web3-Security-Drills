// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Simple vault contract for inspection purposes.
// We will use to analyze and understand how it works under the hood.

contract Vault {
    address public owner;
    uint256 public balance;

    constructor() {
        owner = msg.sender;
    }

    function deposit() external payable {
        balance += msg.value;
    }

    function getBalance() external view returns (uint256) {
        return balance;
    }
}

/**
 * EVM inspection note for this vault contract
 * 1. Compilation pipeline
 * Every Solidity contract goes through four stages before it touches the blockchain:
 * 
 * Stage	   What it is	                         How to see it
 * Solidity	   The code you write	                 Your .sol file
 * Yul	       Intermediate assembly-like language	 forge inspect Vault ir
 * Opcodes	   Human-readable EVM instructions       forge inspect Vault assembly
 * Bytecode	   Raw hex — what lives on-chain	     forge inspect Vault bytecode
 * 
 * Yul is an internal step — you never see it unless you ask. The compiler handles all four stages automatically.
 * 
 * 2. What forge inspect Gives You
 * Run forge build first, then inspect any field:
 * 
 * Run forge build first, then inspect any field:
 * 
 * Command	                                   What you get
 * forge inspect Vault bytecode	               Creation bytecode (deploy + runtime)
 * forge inspect Vault deployedBytecode	       Runtime bytecode only (what lives on-chain)
 * forge inspect Vault assembly	               Opcodes (human-readable)
 * forge inspect Vault methodIdentifiers	   4-byte selectors for every function
 * forge inspect Vault storageLayout	       Which slot each variable lives in
 * forge inspect Vault abi	                   Full ABI JSON
 * forge inspect Vault gasEstimates	           Gas cost per function
 * forge inspect Vault ir	                   Yul intermediate representation
 * 
 * 3. Vault Method Identifiers
 * Vault has four callable functions — two you wrote, two generated automatically by
 * the compiler because owner and balance are public:
 * 
 * 
 * Method	       Selector	     Source
 * deposit()	   d0e30db0	     You wrote this
 * getBalance()	   12065fe0	     You wrote this
 * owner()	       8da5cb5b	     Auto-generated getter (public variable)
 * balance()	   b69ef8a8	     Auto-generated getter (public variable)
 * 
 * Declaring a state variable public automatically creates a getter function with its own
 * selector. The dispatcher handles all four.
 * 
 * 4. Bytecode Structure
 * The bytecode blob has two parts separated by an INVALID opcode (0xfe):
 * 
 * Part	                Runs when?	        Contains
 * Creation bytecode	Once,               at deployment	Constructor, CODECOPY, RETURN
 * Runtime bytecode	    Every transaction	Free memory pointer, dispatcher, functions, helpers, metadata
 * 
 * The creation bytecode copies the runtime bytecode into memory and hands it to the EVM. After deployment the creation bytecode is thrown away — only the runtime bytecode lives on-chain.
 * 
 * 5. Why Every Contract Starts With 6080604052
 * The first five bytes of every Solidity contract are always the same:
 * 
 * Hex	    Opcode	    Meaning
 * 60 80	PUSH1 0x80	Push value 128 onto the stack
 * 60 40	PUSH1 0x40	Push address 64 onto the stack
 * 52	    MSTORE	    Write 128 into memory at address 64

 * This sets up the free memory pointer. Memory address 0x40 always holds the number of the next free memory slot. It starts at 0x80 (128) because everything below is reserved:
 * Memory range	      Reserved for
 * 0x00 – 0x3f	      Scratch space (Solidity hashing operations)
 * 0x40 – 0x5f	      The free memory pointer itself
 * 0x60 – 0x7f	      Zero slot — permanently zero, never write here
 * 0x80 onwards	      Your actual data — safe to use
 * 
 * This is Solidity's bump allocator. When it needs memory it reads 0x40, uses that address, then increments 0x40 by the size used. Memory only grows forward, never freed — wiped at end of transaction.
 * 
 * 6. The Dispatcher
 * After the free memory pointer setup, the dispatcher runs. It reads the first 4 bytes of calldata (the function selector) and routes to the right function:
 * 
 * CALLDATASIZE  ← how many bytes sent?
 * PUSH1 0x04
 * LT            ← less than 4 bytes?
 * JUMPI         ← if yes, revert (no valid selector)
 * 
 * PUSH0
 * CALLDATALOAD  ← load calldata
 * SHR 224       ← isolate first 4 bytes = the selector

 * PUSH4 0xd0e30db0  ← deposit() selector
 * EQ
 * JUMPI             ← match? jump to deposit()

 * PUSH4 0x12065fe0  ← getBalance() selector
 * EQ
 * JUMPI             ← match? jump to getBalance()
 * ... (same for owner() and balance())
 * 
 * REVERT            ← no match — unknown function
 * The EVM has no concept of functions. The dispatcher is just compiler-generated if/else logic using JUMP instructions. Calling a function is literally jumping to a byte offset.
 * 
 * 7. Constructor Payable Guard
 * Your constructor is not marked payable, so the compiler adds an automatic guard:
 * 
 * Hex	   Opcode	             Meaning
 * 34	   CALLVALUE	         How much ETH was sent?
 * 80	   DUP1	                 Duplicate top of stack
 * 15	   ISZERO	             Was it zero?
 * 600e	   PUSH1 0x0e	         Jump destination if true
 * 57	   JUMPI	             Jump if no ETH sent (skip revert)
 * 5f5ffd  PUSH0 PUSH0 REVERT	 ETH was sent — revert transaction
 * 
 * DUP1 is needed because ISZERO consumes the top value. Without duplicating first, the original CALLVALUE would be gone and couldn't be used later.
 * 
 * 8. Key Opcodes Reference
 * 
 * Opcode	       Hex	       What it does
 * PUSH1 x	       60	       Push 1 byte onto stack
 * PUSH2 x	       61	       Push 2 bytes onto stack
 * PUSH32 x	       7f	       Push 32 bytes onto stack
 * DUP1	           80	       Duplicate top stack item
 * SWAP1	       90	       Swap top two stack items
 * MSTORE	       52	       Write 32 bytes to memory
 * MLOAD	       51	       Read 32 bytes from memory
 * SSTORE	       55	       Write to storage (expensive)
 * SLOAD	       54	       Read from storage
 * CALLDATALOAD	   35	       Load 32 bytes of calldata
 * CALLDATASIZE	   36	       Size of calldata in bytes
 * CALLVALUE	   34	       ETH sent with this call (wei)
 * CALLER	       33	       msg.sender address
 * JUMP	           56	       Unconditional jump to offset
 * JUMPI	       57	       Conditional jump
 * JUMPDEST	       5b	       Valid jump destination marker
 * ISZERO	       15	       1 if top is zero, else 0
 * EQ	           14	       1 if top two are equal, else 0
 * GT	           11	       1 if a > b, else 0
 * ADD	           01	       Add top two stack items
 * REVERT	       fd	       Revert with return data
 * RETURN	       f3	       Return with data
 * INVALID	       fe          Hard stop — not executable
 * 
 * 9. Vault Storage Layout
 * Solidity packs state variables into 32-byte slots sequentially:
 * 
 * Slot	Variable	Type	     Notes
 * 0	            owner	     address	Set in constructor: owner = msg.sender
 * 1	            balance	     uint256	Incremented in deposit(): balance += msg.value

 * address(this).balance is the real ETH the contract holds. The balance variable must be kept in sync manually — if you add a receive() function without updating it, they diverge silently.
 *
 * 10. The Bytecode Tail (What You Originally Sent)
 * 
 * The chunk starting at 0x177 is the tail end of the runtime bytecode — helper sub-routines that the main functions jump into:
 * 
 * Offset range	    What it is	                                   Called by
 * 0x178 – 0x19f	uint256 ABI encoder	                           getBalance() return
 * 0x187 – 0x19f	ABI encode wrapper (32-byte output buffer)	   getBalance() return
 * 0x1a0 – 0x1cc	Arithmetic overflow panic (Panic(0x11))	       deposit() overflow check
 * 0x1cd – 0x1ff	Checked addition implementation	               deposit(): balance += msg.value
 * 0x200 onwards	INVALID + CBOR metadata blob	               Not executed — tooling only
 * 
 * The CBOR blob at the end contains the IPFS hash of your source metadata and the compiler version (solc 0.8.30). Etherscan uses this for source verification.
 * 
 * 11. Gas Cost Mental Model
 * 
 * Operation	         Approx gas    	   Why
 * MSTORE / MLOAD	     ~3 gas	           Memory is temporary and cheap
 * Memory expansion	     3 + n²/512	       Grows quadratically past 724 bytes
 * SLOAD (cold)          ~2100 gas	       First read of a storage slot
 * SSTORE (new value)	 ~20,000 gas	   Writing new data to storage
 * SSTORE (update)	     ~2,900 gas	       Updating existing storage slot
 * Stack ops	         ~3 gas	           Pure arithmetic on the stack
 * 
 * Every optimization in Solidity is about doing as much work on the stack and in memory as possible, and touching storage as little as possible.
 * 
 * 12. The Missing Withdraw Function
 * As written, the Vault has no way to get ETH out. Any ETH deposited is locked forever. A safe withdraw would look like:
 * 
 * function withdraw(uint256 amount) external {
 * require(msg.sender == owner, 'not owner');
 * require(amount <= balance, 'insufficient');
 * balance -= amount;                    // update state FIRST
 * payable(owner).transfer(amount);      // then transfer
 * }
 * 
 * Always update state before transferring ETH. If you transfer first and the recipient is a contract, it can re-enter your function before balance is updated — the classic reentrancy attack.
 */
