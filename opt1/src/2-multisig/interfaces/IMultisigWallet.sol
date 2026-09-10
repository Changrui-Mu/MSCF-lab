// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

event Approved(address admin, bytes action);

event Executed(address admin, bytes action);

error NotAuthorized();
error FailedTransfer();
error AlreadyApproved();
error BadConfig();

interface IMultisigWallet {
    function admins(uint256 index) external view returns (address);

    // the ERC20 functions are optional for this checkpoint
    // we'll focus on the ETH transfer functionality only for testing
    function transferEth(address payable recipient, uint256 amount) external;

    function approve(bytes calldata action) external;
    function execute(bytes calldata action) external;
}
