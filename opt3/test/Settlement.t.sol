// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MarketplaceTestBase} from "./MarketplaceTestBase.sol";

/// CHECKPOINT 4 — claimNFT / refund (Q16, Q17, Q18, Q19, Q20)
/// Run with:  forge test --mc Checkpoint4
contract Checkpoint4Settlement is MarketplaceTestBase {
    function setUp() public override {
        super.setUp();
        _openAuction(); // auction open, no bids yet
    }

    // Q16, Q17, Q18, Q19: after a winning bid and the deadline, the winner claims
    // the NFT and the seller is paid the winning amount.
    function test_HappyPath_WinnerClaimsNFT_SellerPaid() public {
        _bid(bidder1, BID1);
        vm.warp(endTime + 1); // auction closes

        uint256 sellerBefore = paymentToken.balanceOf(seller);

        vm.prank(bidder1, bidder1);
        market.claimNFT(AUCTION_INDEX);

        // Q18: the correct token id goes to the winner.
        assertEq(nft.ownerOf(NFT_ID), bidder1, "winner did not receive the NFT");
        // Q19: the seller receives the winning bid.
        assertEq(paymentToken.balanceOf(seller), sellerBefore + BID1, "seller was not paid the winning bid");
    }

    // Q16: the NFT cannot be claimed while the auction is still open.
    function test_RevertWhen_ClaimWhileOpen() public {
        _bid(bidder1, BID1);
        // no warp: still open
        vm.prank(bidder1, bidder1);
        vm.expectRevert("Auction is still open");
        market.claimNFT(AUCTION_INDEX);
    }

    // Q17: only the winning bidder may claim the NFT.
    function test_RevertWhen_NonWinnerClaims() public {
        _bid(bidder1, BID1);
        vm.warp(endTime + 1);
        vm.prank(bidder2, bidder2); // not the winner
        vm.expectRevert("NFT can be claimed only by the current bid owner");
        market.claimNFT(AUCTION_INDEX);
    }

    // Q20: when the auction closed with NO bids, the seller can reclaim the NFT.
    function test_RefundReturnsNFTWhenNoBids() public {
        vm.warp(endTime + 1); // closes with zero bids
        vm.prank(seller, seller);
        market.refund(AUCTION_INDEX);
        assertEq(nft.ownerOf(NFT_ID), seller, "seller did not get the NFT back");
    }

    // Q20: refund must be rejected once there is a winning bidder (no stealing
    // the NFT back from a rightful winner).
    function test_RevertWhen_RefundAfterBid() public {
        _bid(bidder1, BID1);
        vm.warp(endTime + 1);
        vm.prank(seller, seller);
        vm.expectRevert("Existing bider for this auction");
        market.refund(AUCTION_INDEX);
    }

    // Given (claimToken, no blanks): the seller can withdraw tokens after a win,
    // which delivers the NFT to the winner. Sanity check of the settled state.
    function test_ClaimToken_SellerPaid_WinnerGetsNFT() public {
        _bid(bidder1, BID1);
        vm.warp(endTime + 1);

        uint256 sellerBefore = paymentToken.balanceOf(seller);
        vm.prank(seller, seller);
        market.claimToken(AUCTION_INDEX);

        assertEq(paymentToken.balanceOf(seller), sellerBefore + BID1, "seller not paid via claimToken");
        assertEq(nft.ownerOf(NFT_ID), bidder1, "winner did not receive NFT via claimToken");
    }

    // Given (settled flag): an auction settles exactly once — whichever of
    // claimNFT / claimToken runs first blocks the other (and any repeat).
    function test_RevertWhen_SettlingTwice() public {
        _bid(bidder1, BID1);
        vm.warp(endTime + 1);

        vm.prank(bidder1, bidder1);
        market.claimNFT(AUCTION_INDEX);

        vm.prank(seller, seller);
        vm.expectRevert("Auction already settled");
        market.claimToken(AUCTION_INDEX);

        vm.prank(bidder1, bidder1);
        vm.expectRevert("Auction already settled");
        market.claimNFT(AUCTION_INDEX);
    }
}
