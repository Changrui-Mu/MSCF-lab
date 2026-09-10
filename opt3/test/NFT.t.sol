// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {NFTCollection} from "src/NFTCollection.sol";

/// CHECKPOINT 1 — ERC-721 NFT collection (Q7, Q8)
/// Run with:  forge test --mc Checkpoint1
contract Checkpoint1NFTCollection is Test {
    NFTCollection internal nft;
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    function setUp() public {
        nft = new NFTCollection();
    }

    // Q7: a minted NFT is owned by the caller.
    function test_MintGoesToCaller() public {
        vm.prank(alice, alice);
        uint256 id = nft.mintNFT("art", "ipfs://art");
        assertEq(nft.ownerOf(id), alice, "minted NFT not owned by caller (Q7)");
    }

    // Q8: transferNFTFrom moves the token in the requested direction.
    function test_TransferNFTFromMovesToken() public {
        vm.startPrank(alice, alice);
        uint256 id = nft.mintNFT("art", "ipfs://art");
        bool ok = nft.transferNFTFrom(alice, bob, id);
        vm.stopPrank();

        assertTrue(ok, "transferNFTFrom should return true");
        assertEq(nft.ownerOf(id), bob, "NFT did not move to the recipient (Q8)");
    }
}
