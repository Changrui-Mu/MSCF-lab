// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MarketplaceTestBase} from "./MarketplaceTestBase.sol";

/// CHECKPOINT 2 — createAuction (Q9, Q10, Q11)
/// Run with:  forge test --mc Checkpoint2
contract Checkpoint2CreateAuction is MarketplaceTestBase {
    // Happy path: a valid auction is recorded AND the NFT is moved into escrow.
    // Fails unless Q9, Q10, Q11 are all answered correctly (Q11 in particular is
    // what actually pulls the NFT into the marketplace).
    function test_HappyPath_OpensAuctionAndEscrowsNFT() public {
        _openAuction();

        assertEq(market.index(), 1, "auction counter should be 1 after one creation");
        assertEq(market.getCurrentBid(AUCTION_INDEX), INITIAL_BID, "starting price wrong");
        assertEq(market.getCurrentBidOwner(AUCTION_INDEX), address(0), "no bidder yet");
        // Q11: the NFT must now be held by the marketplace (escrowed).
        assertEq(nft.ownerOf(NFT_ID), address(market), "NFT was not escrowed into the marketplace");
    }

    // Q9: a non-owner must not be able to auction someone else's NFT.
    function test_RevertWhen_CallerIsNotOwner() public {
        vm.startPrank(seller, seller);
        nft.mintNFT("decoy", "ipfs://decoy"); // id 0
        nft.mintNFT("prize", "ipfs://prize"); // id 1
        nft.approve(address(market), NFT_ID);
        vm.stopPrank();

        // bidder1 (not the owner) tries to open the auction.
        vm.prank(bidder1, bidder1);
        vm.expectRevert("Caller is not the owner of the NFT");
        market.createAuction(address(nft), address(paymentToken), NFT_ID, INITIAL_BID, block.timestamp + AUCTION_DURATION);
    }

    // Q10: without the marketplace being approved, creation must be rejected with
    // the approval-specific error (not a generic ERC721 revert).
    function test_RevertWhen_MarketplaceNotApproved() public {
        vm.startPrank(seller, seller);
        nft.mintNFT("decoy", "ipfs://decoy"); // id 0
        nft.mintNFT("prize", "ipfs://prize"); // id 1
        // deliberately DO NOT approve
        vm.expectRevert("Require NFT ownership transfer approval");
        market.createAuction(address(nft), address(paymentToken), NFT_ID, INITIAL_BID, block.timestamp + AUCTION_DURATION);
        vm.stopPrank();
    }

    // Given validation (sanity): a past end date is rejected.
    function test_RevertWhen_EndDateInPast() public {
        vm.startPrank(seller, seller);
        nft.mintNFT("decoy", "ipfs://decoy");
        nft.mintNFT("prize", "ipfs://prize");
        nft.approve(address(market), NFT_ID);
        vm.expectRevert("Invalid end date for auction");
        market.createAuction(address(nft), address(paymentToken), NFT_ID, INITIAL_BID, block.timestamp);
        vm.stopPrank();
    }

    // Given validation (sanity): a zero starting bid is rejected.
    function test_RevertWhen_InitialBidZero() public {
        vm.startPrank(seller, seller);
        nft.mintNFT("decoy", "ipfs://decoy");
        nft.mintNFT("prize", "ipfs://prize");
        nft.approve(address(market), NFT_ID);
        vm.expectRevert("Invalid initial bid price");
        market.createAuction(address(nft), address(paymentToken), NFT_ID, 0, block.timestamp + AUCTION_DURATION);
        vm.stopPrank();
    }
}
