// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MarketplaceTestBase} from "./MarketplaceTestBase.sol";

/// CHECKPOINT 3 — bid (Q12, Q13, Q14, Q15)
/// Run with:  forge test --mc Checkpoint3
contract Checkpoint3Bidding is MarketplaceTestBase {
    function setUp() public override {
        super.setUp();
        _openAuction();
    }

    // Q14: a bid escrows the bidder's tokens into the marketplace and updates the
    // standing bid.
    function test_HappyPath_BidEscrowsTokens() public {
        uint256 before = paymentToken.balanceOf(bidder1);

        _bid(bidder1, BID1);

        assertEq(paymentToken.balanceOf(bidder1), before - BID1, "bidder was not debited");
        assertEq(paymentToken.balanceOf(address(market)), BID1, "tokens not locked in marketplace");
        assertEq(market.getCurrentBid(AUCTION_INDEX), BID1, "standing bid not updated");
        assertEq(market.getCurrentBidOwner(AUCTION_INDEX), bidder1, "bid owner not updated");
    }

    // Q12: a bid that merely equals the starting price must be rejected.
    function test_RevertWhen_BidEqualsStartingPrice() public {
        vm.startPrank(bidder1, bidder1);
        paymentToken.approve(address(market), INITIAL_BID);
        vm.expectRevert("New bid price must be higher than the current bid");
        market.bid(AUCTION_INDEX, INITIAL_BID);
        vm.stopPrank();
    }

    // Q12: a bid equal to the current highest bid must be rejected.
    function test_RevertWhen_BidNotStrictlyHigher() public {
        _bid(bidder1, BID1);
        vm.startPrank(bidder2, bidder2);
        paymentToken.approve(address(market), BID1);
        vm.expectRevert("New bid price must be higher than the current bid");
        market.bid(AUCTION_INDEX, BID1);
        vm.stopPrank();
    }

    // Q13: the auction creator cannot bid on their own auction.
    function test_RevertWhen_CreatorBids() public {
        vm.prank(seller, seller);
        vm.expectRevert("Creator of the auction cannot place new bid");
        market.bid(AUCTION_INDEX, BID1);
    }

    // Q15: when out-bid, the previous highest bidder is refunded EXACTLY their
    // own escrowed amount, and the marketplace keeps only the new top bid.
    function test_PreviousBidderRefundedExactly() public {
        _bid(bidder1, BID1);
        uint256 b1AfterFirst = paymentToken.balanceOf(bidder1); // FUNDING - BID1

        _bid(bidder2, BID2);

        assertEq(paymentToken.balanceOf(bidder1), b1AfterFirst + BID1, "previous bidder not refunded exactly");
        assertEq(paymentToken.balanceOf(address(market)), BID2, "marketplace should hold only the top bid");
        assertEq(market.getCurrentBidOwner(AUCTION_INDEX), bidder2, "new bid owner wrong");
        assertEq(market.getCurrentBid(AUCTION_INDEX), BID2, "new standing bid wrong");
    }

    // Given validation (sanity): bidding on a non-existent auction reverts.
    function test_RevertWhen_AuctionIndexInvalid() public {
        vm.startPrank(bidder1, bidder1);
        paymentToken.approve(address(market), BID1);
        vm.expectRevert("Invalid auction index");
        market.bid(99, BID1);
        vm.stopPrank();
    }
}
