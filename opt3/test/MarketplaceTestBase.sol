// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {ERC20} from "src/ERC20.sol";
import {NFTCollection} from "src/NFTCollection.sol";
import {Marketplace} from "src/Marketplace.sol";

/// Shared fixtures for every checkpoint.
///
/// Actors:
///   • seller   — mints the NFT and opens the auction (the auction "creator").
///   • bidder1  — places the first bid.
///   • bidder2  — out-bids bidder1.
///
/// Important detail used by Q18: the seller mints TWO NFTs (token ids 0 and 1)
/// but auctions token id 1, while the auction itself lives at array index 0.
/// So nftId (1) != auctionIndex (0): a solution that confuses the two will move
/// the wrong token and revert.
abstract contract MarketplaceTestBase is Test {
    ERC20 internal paymentToken;
    NFTCollection internal nft;
    Marketplace internal market;

    address internal seller = makeAddr("seller");
    address internal bidder1 = makeAddr("bidder1");
    address internal bidder2 = makeAddr("bidder2");

    uint256 internal constant INITIAL_BID = 50 ether;
    uint256 internal constant BID1 = 100 ether;
    uint256 internal constant BID2 = 200 ether;
    uint256 internal constant AUCTION_DURATION = 1 days;
    uint256 internal constant FUNDING = 10_000 ether;

    uint256 internal constant AUCTION_INDEX = 0; // first auction's array index
    uint256 internal constant NFT_ID = 1; // token id under auction (!= index)

    uint256 internal endTime; // set by _openAuction

    function setUp() public virtual {
        // The test contract deploys the token and holds the entire supply,
        // then funds the two bidders.
        paymentToken = new ERC20(1_000_000, "Pay Token", "PAY");
        nft = new NFTCollection();
        market = new Marketplace("CMU Marketplace");

        paymentToken.transfer(bidder1, FUNDING);
        paymentToken.transfer(bidder2, FUNDING);
    }

    /// Seller mints two NFTs, approves the marketplace for token id 1, and opens
    /// an auction for it. Afterwards the auction is at AUCTION_INDEX (0).
    function _openAuction() internal {
        endTime = block.timestamp + AUCTION_DURATION;
        // Two-arg prank: msg.sender AND tx.origin are the seller, matching how a
        // real EOA transaction looks.
        vm.startPrank(seller, seller);
        nft.mintNFT("decoy", "ipfs://decoy"); // token id 0, stays with seller
        nft.mintNFT("prize", "ipfs://prize"); // token id 1, to be auctioned
        nft.approve(address(market), NFT_ID);
        market.createAuction(address(nft), address(paymentToken), NFT_ID, INITIAL_BID, endTime);
        vm.stopPrank();
    }

    /// Approve the marketplace for `amount` and place a bid as `who`.
    function _bid(address who, uint256 amount) internal {
        vm.startPrank(who, who);
        paymentToken.approve(address(market), amount);
        market.bid(AUCTION_INDEX, amount);
        vm.stopPrank();
    }
}
