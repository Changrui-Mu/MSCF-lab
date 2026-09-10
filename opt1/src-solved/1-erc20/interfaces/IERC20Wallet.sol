// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

error NotAuthorized();
error FailedTransfer();

interface IERC20Wallet {
    function owner() external view returns (address);
    function transferEth(address payable recipient, uint256 amount) external;
    function transferERC20(address token, address recipient, uint256 amount) external;
    function approveERC20(address token, address spender, uint256 amount) external;
}
