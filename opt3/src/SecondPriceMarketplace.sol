// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./ERC20.sol";
import "./NFTCollection.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

/*
 * ┌───────────────────────────────────────────────────────────────────────────┐
 * │  QUESTION 1 / CHECKPOINT 5 - SECOND-PRICE AUCTION (write-it-yourself)      │
 * │                                                                            │
 * │  WRITE the three missing pieces of code yourself — they are marked         │
 * │  ">>> YOUR CODE (k/3)", and each box says exactly what your code must do.  │
 * │  Everything else is given and mirrors Marketplace.sol, which you have      │
 * │  already completed — only the PAYMENT RULE changes.                        │
 * │                                                                            │
 * │    forge test --mc Checkpoint5                                             │
 * └───────────────────────────────────────────────────────────────────────────┘
 *
 * ─── Why a second-price auction? ─────────────────────────────────────────────
 * In the first-price auction of Marketplace.sol the winner pays their own bid.
 * That forces bidders to strategize: bid your true value and you overpay; the
 * optimal move is to shade your bid below your value, by an amount that
 * depends on what everyone ELSE might bid.
 *
 * In a SECOND-PRICE auction (Vickrey, Nobel Prize 1996), the highest bidder
 * still wins — but pays only the SECOND-highest price. This one change makes
 * truthful bidding the dominant strategy: your bid decides only WHETHER you
 * win, never how much you pay, so shading down can only ever lose you an
 * auction you'd have profitably won. eBay's proxy bidding works this way, and
 * ad exchanges ran on second-price auctions for years.
 *
 * The classic Vickrey auction is sealed-bid. Ours keeps the open, ascending
 * format (each bid must still beat the highest standing bid — that part is
 * unchanged) and applies the second-price rule at SETTLEMENT:
 *
 *   • the seller receives the second-highest price;
 *   • the winner escrowed their full bid, so the difference
 *     (their bid − second price) must be returned to them;
 *   • if only one bid was ever placed, the "second price" is the seller's
 *     starting price — the winner pays the reserve.
 *
 * Bookkeeping: the struct gains ONE field, `secondBidPrice`. It starts at the
 * seller's initial price and must always hold the highest DISPLACED price —
 * maintaining it is your job in the bid function.
 *
 * Worked example (starting price 50):
 *   bid1 = 100  →  currentBidPrice 100, secondBidPrice 50
 *   bid2 = 200  →  currentBidPrice 200, secondBidPrice 100
 *   settlement  →  seller receives 100, winner is refunded 200 − 100 = 100,
 *                  marketplace escrow ends at exactly 0.
 */
contract SecondPriceMarketplace is IERC721Receiver {
    string public name;
    uint256 public index = 0;

    struct Auction {
        uint256 index;
        address addressNFTCollection;
        address addressPaymentToken;
        uint256 nftId;
        address creator;
        address payable currentBidOwner; // Highest bidder
        uint256 currentBidPrice; // Highest bid amount
        uint256 secondBidPrice; // Second-highest price — what the winner PAYS
        uint256 endAuction;
        uint256 bidCount;
        bool settled; // Set the moment the auction pays out — blocks double settlement
    }

    Auction[] private allAuctions;

    event NewAuction(uint256 index, uint256 nftId, address creator, uint256 startingPrice, uint256 endAuction);
    event NewBidOnAuction(uint256 auctionIndex, uint256 newBid);
    event NFTClaimed(uint256 auctionIndex, uint256 nftId, address claimedBy, uint256 pricePaid);
    event TokensClaimed(uint256 auctionIndex, uint256 nftId, address claimedBy, uint256 pricePaid);
    event NFTRefunded(uint256 auctionIndex, uint256 nftId, address claimedBy);

    constructor(string memory _name) {
        name = _name;
    }

    function isContract(address _addr) private view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(_addr)
        }
        return size > 0;
    }

    // Open an auction (given — same checks you chose in Q9-Q11, already filled
    // in). Note the ONE difference: secondBidPrice starts at the seller's
    // initial price, so a single-bid auction settles at the reserve.
    function createAuction(
        address _addressNFTCollection,
        address _addressPaymentToken,
        uint256 _nftId,
        uint256 _initialBid,
        uint256 _endAuction
    ) external returns (uint256) {
        require(isContract(_addressNFTCollection), "Invalid NFT Collection contract address");
        require(isContract(_addressPaymentToken), "Invalid Payment Token contract address");
        require(_endAuction > block.timestamp, "Invalid end date for auction");
        require(_initialBid > 0, "Invalid initial bid price");

        NFTCollection nftCollection = NFTCollection(_addressNFTCollection);
        require(nftCollection.ownerOf(_nftId) == msg.sender, "Caller is not the owner of the NFT");
        require(nftCollection.getApproved(_nftId) == address(this), "Require NFT ownership transfer approval");
        require(nftCollection.transferNFTFrom(msg.sender, address(this), _nftId));

        allAuctions.push(
            Auction({
                index: index,
                addressNFTCollection: _addressNFTCollection,
                addressPaymentToken: _addressPaymentToken,
                nftId: _nftId,
                creator: msg.sender,
                currentBidOwner: payable(address(0)),
                currentBidPrice: _initialBid,
                secondBidPrice: _initialBid, // reserve = second price until real bids arrive
                endAuction: _endAuction,
                bidCount: 0,
                settled: false
            })
        );
        index++;

        emit NewAuction(index - 1, _nftId, msg.sender, _initialBid, _endAuction);
        return index - 1;
    }

    function isOpen(uint256 _auctionIndex) public view returns (bool) {
        return block.timestamp < allAuctions[_auctionIndex].endAuction;
    }

    function getCurrentBidOwner(uint256 _auctionIndex) public view returns (address) {
        require(_auctionIndex < allAuctions.length, "Invalid auction index");
        return allAuctions[_auctionIndex].currentBidOwner;
    }

    function getCurrentBid(uint256 _auctionIndex) public view returns (uint256) {
        require(_auctionIndex < allAuctions.length, "Invalid auction index");
        return allAuctions[_auctionIndex].currentBidPrice;
    }

    function getSecondBid(uint256 _auctionIndex) public view returns (uint256) {
        require(_auctionIndex < allAuctions.length, "Invalid auction index");
        return allAuctions[_auctionIndex].secondBidPrice;
    }

    // Place a bid. The guards, the escrow pull, and the refund of the out-bid
    // bidder are given — they are exactly what you built in Q12-Q15.
    function bid(uint256 _auctionIndex, uint256 _newBid) external returns (bool) {
        require(_auctionIndex < allAuctions.length, "Invalid auction index");
        Auction storage auction = allAuctions[_auctionIndex];
        require(isOpen(_auctionIndex), "Auction is not open");
        require(_newBid > auction.currentBidPrice, "New bid price must be higher than the current bid");
        require(msg.sender != auction.creator, "Creator of the auction cannot place new bid");

        ERC20 paymentToken = ERC20(auction.addressPaymentToken);
        require(paymentToken.transferFrom(msg.sender, address(this), _newBid), "Tranfer of token failed");

        // Refund the displaced highest bidder their full escrowed bid (given).
        if (auction.bidCount > 0) {
            paymentToken.transfer(auction.currentBidOwner, auction.currentBidPrice);
        }

        /* ┌─────────────────────────────────────────────────────────────────┐
         * │ >>> YOUR CODE (1/3): maintain the second price                   │
         * │ A new highest bid is about to be recorded below. At this moment, │
         * │ which existing number becomes the auction's second-highest       │
         * │ price? Update `auction.secondBidPrice` accordingly (1 line).     │
         * │ Check your answer against the worked example in the header —     │
         * │ it must hold for the FIRST bid too (reserve case).               │
         * └─────────────────────────────────────────────────────────────────┘ */

        // Record the new highest bid (given):
        auction.currentBidOwner = payable(msg.sender);
        auction.currentBidPrice = _newBid;
        auction.bidCount++;

        emit NewBidOnAuction(_auctionIndex, _newBid);
        return true;
    }

    // Winner withdraws the NFT and pays the SECOND price; the difference
    // against their escrowed bid comes back to them. (Given — the actual
    // pay-out rule lives in _settle below, which is where your code goes.)
    function claimNFT(uint256 _auctionIndex) external {
        require(_auctionIndex < allAuctions.length, "Invalid auction index");
        require(!isOpen(_auctionIndex), "Auction is still open");

        Auction storage auction = allAuctions[_auctionIndex];
        require(auction.currentBidOwner == msg.sender, "NFT can be claimed only by the current bid owner");

        _settle(auction);
        emit NFTClaimed(_auctionIndex, auction.nftId, msg.sender, auction.secondBidPrice);
    }

    // Seller-side settlement (given). Without this, a winner who never calls
    // claimNFT would leave BOTH the seller's proceeds and the NFT stuck in
    // escrow forever — the seller must be able to force settlement too. Note
    // the winner still receives the NFT; who initiates changes nothing about
    // who gets what.
    function claimToken(uint256 _auctionIndex) external {
        require(_auctionIndex < allAuctions.length, "Invalid auction index");
        require(!isOpen(_auctionIndex), "Auction is still open");

        Auction storage auction = allAuctions[_auctionIndex];
        require(auction.creator == msg.sender, "Tokens can be claimed only by the creator of the auction");
        require(auction.currentBidOwner != address(0), "No bids to settle");

        _settle(auction);
        emit TokensClaimed(_auctionIndex, auction.nftId, msg.sender, auction.secondBidPrice);
    }

    // Shared settlement path: whichever of claimNFT / claimToken runs first
    // executes this exactly once (the `settled` flag blocks the second). NFT
    // to the winner, then the escrowed tokens are split by the second-price
    // rule — that split is YOUR CODE below.
    function _settle(Auction storage auction) internal {
        require(!auction.settled, "Auction already settled");
        auction.settled = true; // effects before interactions

        NFTCollection nftCollection = NFTCollection(auction.addressNFTCollection);
        require(nftCollection.transferNFTFrom(address(this), auction.currentBidOwner, auction.nftId));

        ERC20 paymentToken = ERC20(auction.addressPaymentToken);

        /* ┌─────────────────────────────────────────────────────────────────┐
         * │ >>> YOUR CODE (2/3): pay the seller                              │
         * │ Under the second-price rule, how much of the escrowed money      │
         * │ belongs to the seller? Send it (1 line).                         │
         * └─────────────────────────────────────────────────────────────────┘ */

        /* ┌─────────────────────────────────────────────────────────────────┐
         * │ >>> YOUR CODE (3/3): refund the winner the difference            │
         * │ The winner escrowed their FULL bid but owes only the second      │
         * │ price. Return the difference (1 line). After this, the           │
         * │ marketplace's token balance for this auction must be exactly 0   │
         * │ — the tests check that no money is stranded or minted.           │
         * └─────────────────────────────────────────────────────────────────┘ */
    }

    // Seller reclaims the NFT when the auction closed with no bids (given).
    function refund(uint256 _auctionIndex) external {
        require(_auctionIndex < allAuctions.length, "Invalid auction index");
        require(!isOpen(_auctionIndex), "Auction is still open");

        Auction storage auction = allAuctions[_auctionIndex];
        require(auction.creator == msg.sender, "NFT can be refunded only to the creator of the auction");
        require(auction.currentBidOwner == address(0), "Existing bider for this auction");
        require(!auction.settled, "Auction already settled");
        auction.settled = true;

        NFTCollection nftCollection = NFTCollection(auction.addressNFTCollection);
        require(nftCollection.transferNFTFrom(address(this), auction.creator, auction.nftId));

        emit NFTRefunded(_auctionIndex, auction.nftId, msg.sender);
    }

    function onERC721Received(address, address, uint256, bytes memory)
        public
        virtual
        override
        returns (bytes4)
    {
        return this.onERC721Received.selector;
    }
}
