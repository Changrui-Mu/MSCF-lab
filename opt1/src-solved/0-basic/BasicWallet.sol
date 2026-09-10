// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./interfaces/IBasicWallet.sol";

contract BasicWallet is IBasicWallet {
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
}
