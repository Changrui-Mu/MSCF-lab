// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "src/ERC20.sol";
import {NFTCollection} from "src/NFTCollection.sol";
import {SecondPriceMarketplace} from "src/SecondPriceMarketplace.sol";

/// CHECKPOINT 5 — second-price auction (write-it-yourself)
/// Run with:  forge test --mc Checkpoint5
///
/// The money-conservation assertions are the heart of this suite: after
/// settlement the marketplace must hold EXACTLY zero tokens — every wei of
/// escrow either went to the seller (second price) or back to the winner
/// (the difference). A wrong second-price update strands or leaks tokens.
contract Checkpoint5SecondPrice is Test {
    ERC20 internal paymentToken;
    NFTCollection internal nft;
    SecondPriceMarketplace internal market;

    address internal seller = makeAddr("seller");
    address internal bidder1 = makeAddr("bidder1");
    address internal bidder2 = makeAddr("bidder2");

    uint256 internal constant STARTING_PRICE = 50 ether;
    uint256 internal constant BID1 = 100 ether;
    uint256 internal constant BID2 = 200 ether;
    uint256 internal constant BID3 = 300 ether;
    uint256 internal constant FUNDING = 10_000 ether;
    uint256 internal constant AUCTION_DURATION = 1 days;

    uint256 internal constant AUCTION_INDEX = 0;
    uint256 internal constant NFT_ID = 1; // token id under auction (!= index)

    uint256 internal endTime;

    function setUp() public {
        paymentToken = new ERC20(1_000_000, "Pay Token", "PAY");
        nft = new NFTCollection();
        market = new SecondPriceMarketplace("CMU Second-Price Marketplace");

        paymentToken.transfer(bidder1, FUNDING);
        paymentToken.transfer(bidder2, FUNDING);
    }

    function _openAuction() internal {
        endTime = block.timestamp + AUCTION_DURATION;
        vm.startPrank(seller, seller);
        nft.mintNFT("decoy", "ipfs://decoy"); // token id 0, stays with seller
        nft.mintNFT("prize", "ipfs://prize"); // token id 1, auctioned
        nft.approve(address(market), NFT_ID);
        market.createAuction(address(nft), address(paymentToken), NFT_ID, STARTING_PRICE, endTime);
        vm.stopPrank();
    }

    function _bid(address who, uint256 amount) internal {
        vm.startPrank(who, who);
        paymentToken.approve(address(market), amount);
        market.bid(AUCTION_INDEX, amount);
        vm.stopPrank();
    }

    // (1/3)+(2/3)+(3/3): with two bids, the winner pays the SECOND-highest
    // price, the loser is made whole, and no tokens are stranded in escrow.
    function test_WinnerPaysSecondPrice() public {
        _openAuction();
        _bid(bidder1, BID1);
        _bid(bidder2, BID2);

        vm.warp(endTime + 1);
        vm.prank(bidder2);
        market.claimNFT(AUCTION_INDEX);

        assertEq(nft.ownerOf(NFT_ID), bidder2, "NFT did not go to the winner");
        assertEq(paymentToken.balanceOf(seller), BID1, "seller must receive the SECOND price (bidder1's bid)");
        assertEq(paymentToken.balanceOf(bidder2), FUNDING - BID1, "winner must pay only the second price");
        assertEq(paymentToken.balanceOf(bidder1), FUNDING, "out-bid bidder must be fully refunded");
        assertEq(paymentToken.balanceOf(address(market)), 0, "escrow must be empty after settlement");
    }

    // (1/3): with a single bid, the second price is the seller's starting
    // price — the winner pays the reserve, not their own bid.
    function test_SingleBidderPaysReservePrice() public {
        _openAuction();
        _bid(bidder1, BID1);

        vm.warp(endTime + 1);
        vm.prank(bidder1);
        market.claimNFT(AUCTION_INDEX);

        assertEq(nft.ownerOf(NFT_ID), bidder1, "NFT did not go to the winner");
        assertEq(paymentToken.balanceOf(seller), STARTING_PRICE, "seller must receive the reserve price");
        assertEq(paymentToken.balanceOf(bidder1), FUNDING - STARTING_PRICE, "sole bidder must pay only the reserve");
        assertEq(paymentToken.balanceOf(address(market)), 0, "escrow must be empty after settlement");
    }

    // (1/3): the second price must track the top TWO bids, not the first two.
    // bidder1 bids 100, bidder2 bids 200, bidder1 comes back with 300:
    // winner = bidder1, second price = 200.
    function test_SecondPriceTracksTopTwoBids() public {
        _openAuction();
        _bid(bidder1, BID1);
        _bid(bidder2, BID2);
        _bid(bidder1, BID3);

        assertEq(market.getSecondBid(AUCTION_INDEX), BID2, "second price must be the displaced highest bid");

        vm.warp(endTime + 1);
        vm.prank(bidder1);
        market.claimNFT(AUCTION_INDEX);

        assertEq(nft.ownerOf(NFT_ID), bidder1, "NFT did not go to the winner");
        assertEq(paymentToken.balanceOf(seller), BID2, "seller must receive the second-highest bid");
        assertEq(paymentToken.balanceOf(bidder1), FUNDING - BID2, "winner's net cost must equal the second price");
        assertEq(paymentToken.balanceOf(bidder2), FUNDING, "out-bid bidder must be fully refunded");
        assertEq(paymentToken.balanceOf(address(market)), 0, "escrow must be empty after settlement");
    }

    // Given behavior carried over: a no-bid auction refunds the NFT to the
    // seller after the deadline.
    function test_RefundReturnsNFTWhenNoBids() public {
        _openAuction();
        vm.warp(endTime + 1);
        vm.prank(seller);
        market.refund(AUCTION_INDEX);
        assertEq(nft.ownerOf(NFT_ID), seller, "seller did not get the NFT back");
    }

    // Given (claimToken): the seller can force settlement if the winner never
    // claims — same split as claimNFT, only the initiator differs.
    function test_ClaimToken_SellerForcesSettlement() public {
        _openAuction();
        _bid(bidder1, BID1);
        _bid(bidder2, BID2);

        vm.warp(endTime + 1);
        vm.prank(seller);
        market.claimToken(AUCTION_INDEX);

        assertEq(nft.ownerOf(NFT_ID), bidder2, "NFT did not go to the winner");
        assertEq(paymentToken.balanceOf(seller), BID1, "seller must receive the second price");
        assertEq(paymentToken.balanceOf(bidder2), FUNDING - BID1, "winner must pay only the second price");
        assertEq(paymentToken.balanceOf(address(market)), 0, "escrow must be empty after settlement");
    }

    // Given (settled flag): settlement runs exactly once across both paths.
    function test_RevertWhen_SettlingTwice() public {
        _openAuction();
        _bid(bidder1, BID1);

        vm.warp(endTime + 1);
        vm.prank(bidder1);
        market.claimNFT(AUCTION_INDEX);

        vm.prank(seller);
        vm.expectRevert("Auction already settled");
        market.claimToken(AUCTION_INDEX);
    }
}
