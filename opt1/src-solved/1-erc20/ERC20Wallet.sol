// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./interfaces/IERC20Wallet.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract ERC20Wallet is IERC20Wallet {
    using SafeERC20 for IERC20;

    address public owner;

    constructor() {
        owner = msg.sender;
    }

    receive() external payable {}

    function transferEth(address payable recipient, uint256 amount) external {
        if (msg.sender != owner) revert NotAuthorized();
        (bool ok,) = recipient.call{value: amount}("");
        if (!ok) revert FailedTransfer();
    }

    function transferERC20(address token, address recipient, uint256 amount) external {
        if (msg.sender != owner) revert NotAuthorized();
        IERC20(token).safeTransfer(recipient, amount);
    }

    function approveERC20(address token, address spender, uint256 amount) external {
        if (msg.sender != owner) revert NotAuthorized();
        IERC20(token).forceApprove(spender, amount);
    }
}
