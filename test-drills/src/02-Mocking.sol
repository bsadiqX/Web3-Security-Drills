// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface IERC20 {
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);

    function balanceOf(address account) external view returns (uint256);
}

contract Vault {
    IERC20 public immutable token;

    mapping(address => uint256) public balances;

    event Deposited(address indexed user, uint256 amount);

    constructor(address _token) {
        require(_token != address(0), "Zero address");
        token = IERC20(_token);
    }

    function deposit(uint256 _amount) external {
        require(_amount > 0, "Amount zero");

        bool success = token.transferFrom(
            msg.sender,
            address(this),
            _amount
        );

        require(success, "Transfer failed");

        balances[msg.sender] += _amount;

        emit Deposited(msg.sender, _amount);
    }
}