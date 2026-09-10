// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

error NotAuthorized();
error FailedTransfer();

interface IBasicWallet {
    function owner() external view returns (address);
    function transferEth(address payable recipient, uint256 amount) external;
}
