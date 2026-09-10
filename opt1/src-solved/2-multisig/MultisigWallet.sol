// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./interfaces/IMultisigWallet.sol";

contract MultisigWallet is IMultisigWallet {
    uint256 public constant ADMIN_COUNT = 3;
    uint256 public constant THRESHOLD = 2;

    address[] public admins;
    mapping(bytes32 => mapping(address => bool)) public approvalsBy;
    mapping(bytes32 => uint256) public approvalCount;
    mapping(bytes32 => bool) public executed;

    constructor(address[] memory _admins) {
        if (_admins.length != ADMIN_COUNT) revert BadConfig();
        for (uint256 i = 0; i < ADMIN_COUNT; i++) {
            for (uint256 j = i + 1; j < ADMIN_COUNT; j++) {
                if (_admins[i] == _admins[j]) revert BadConfig();
            }
        }
        admins = _admins;
    }

    receive() external payable {}

    function _isAdmin(address account) internal view returns (bool) {
        for (uint256 i = 0; i < ADMIN_COUNT; i++) {
            if (admins[i] == account) return true;
        }
        return false;
    }

    function approve(bytes calldata action) external {
        if (!_isAdmin(msg.sender)) revert NotAuthorized();
        bytes32 h = keccak256(action);
        if (approvalsBy[h][msg.sender]) revert AlreadyApproved();
        approvalsBy[h][msg.sender] = true;
        approvalCount[h] += 1;
        emit Approved(msg.sender, action);
    }

    function execute(bytes calldata action) external {
        bytes32 h = keccak256(action);
        if (executed[h]) revert NotAuthorized();

        if (_isAdmin(msg.sender) && !approvalsBy[h][msg.sender]) {
            approvalsBy[h][msg.sender] = true;
            approvalCount[h] += 1;
            emit Approved(msg.sender, action);
        }

        if (approvalCount[h] < THRESHOLD) revert NotAuthorized();
        executed[h] = true;
        (bool success,) = address(this).call(action);
        require(success);
        emit Executed(msg.sender, action);
    }

    function transferEth(address payable recipient, uint256 amount) external {
        if (msg.sender != address(this)) revert NotAuthorized();
        (bool ok,) = recipient.call{value: amount}("");
        if (!ok) revert FailedTransfer();
    }
}
