// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract SimpleHTLC {
    address public sender;
    address public receiver;
    bytes32 public hashlock;
    uint256 public deadline;
    bool public settled;

    constructor(address _receiver, bytes32 _hashlock, uint256 _deadline) payable {
        sender = msg.sender;
        receiver = _receiver;
        hashlock = _hashlock;
        deadline = _deadline;
    }

    function withdraw(bytes32 secret) external {
        require(!settled, "already settled");
        require(block.timestamp < deadline, "too late");
        require(sha256(abi.encodePacked(secret)) == hashlock, "wrong secret");
        settled = true;
        payable(receiver).transfer(address(this).balance);
    }

    function refund() external {
        require(msg.sender == sender, "not the sender");
        require(block.timestamp >= deadline, "too early");
        require(!settled, "already settled");
        settled = true;
        payable(sender).transfer(address(this).balance);
    }
}
