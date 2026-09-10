// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts@5.4.0/token/ERC721/IERC721.sol";

contract SimpleNFTHTLC {
    address public sender;
    address public receiver;
    IERC721 public nft;
    uint256 public tokenId;
    bytes32 public hashlock;
    uint256 public deadline;
    bool public locked;
    bool public settled;

    constructor(address _nft, uint256 _tokenId, address _receiver, bytes32 _hashlock, uint256 _deadline) {
        sender = msg.sender;
        nft = IERC721(_nft);
        tokenId = _tokenId;
        receiver = _receiver;
        hashlock = _hashlock;
        deadline = _deadline;
    }

    function lock() external {
        require(msg.sender == sender, "not the sender");
        require(!locked, "already locked");
        locked = true;
        nft.transferFrom(sender, address(this), tokenId);
    }

    function withdraw(bytes32 secret) external {
        require(locked, "not locked");
        require(!settled, "already settled");
        require(block.timestamp < deadline, "too late");
        require(sha256(abi.encodePacked(secret)) == hashlock, "wrong secret");
        settled = true;
        nft.safeTransferFrom(address(this), receiver, tokenId);
    }

    function refund() external {
        require(msg.sender == sender, "not the sender");
        require(locked, "not locked");
        require(block.timestamp >= deadline, "too early");
        require(!settled, "already settled");
        settled = true;
        nft.safeTransferFrom(address(this), sender, tokenId);
    }
}
