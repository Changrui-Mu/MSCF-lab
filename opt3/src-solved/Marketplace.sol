// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./ERC20.sol";
import "./NFTCollection.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract Marketplace is IERC721Receiver {
    string public name;
    uint256 public index;

    struct Auction {
        uint256 index;
        address addressNFTCollection;
        address addressPaymentToken;
        uint256 nftId;
        address creator;
        address payable currentBidOwner;
        uint256 currentBidPrice;
        uint256 endAuction;
        uint256 bidCount;
        bool settled;
    }

    Auction[] private allAuctions;

    event NewAuction(
        uint256 index,
        address addressNFTCollection,
        address addressPaymentToken,
        uint256 nftId,
        address mintedBy,
        address currentBidOwner,
        uint256 currentBidPrice,
        uint256 endAuction,
        uint256 bidCount
    );
    event NewBidOnAuction(uint256 auctionIndex, uint256 newBid);
    event NFTClaimed(uint256 auctionIndex, uint256 nftId, address claimedBy);
    event TokensClaimed(uint256 auctionIndex, uint256 nftId, address claimedBy);
    event NFTRefunded(uint256 auctionIndex, uint256 nftId, address claimedBy);

    constructor(string memory marketplaceName) {
        name = marketplaceName;
    }

    function isContract(address account) private view returns (bool) {
        return account.code.length > 0;
    }

    function createAuction(
        address addressNFTCollection,
        address addressPaymentToken,
        uint256 nftId,
        uint256 initialBid,
        uint256 endAuction
    ) external returns (uint256) {
        require(isContract(addressNFTCollection), "Invalid NFT Collection contract address");
        require(isContract(addressPaymentToken), "Invalid Payment Token contract address");
        require(endAuction > block.timestamp, "Invalid end date for auction");
        require(initialBid > 0, "Invalid initial bid price");

        NFTCollection nftCollection = NFTCollection(addressNFTCollection);
        require(nftCollection.ownerOf(nftId) == msg.sender, "Caller is not the owner of the NFT");
        require(nftCollection.getApproved(nftId) == address(this), "Require NFT ownership transfer approval");
        require(nftCollection.transferNFTFrom(msg.sender, address(this), nftId));

        Auction memory newAuction = Auction({
            index: index,
            addressNFTCollection: addressNFTCollection,
            addressPaymentToken: addressPaymentToken,
            nftId: nftId,
            creator: msg.sender,
            currentBidOwner: payable(address(0)),
            currentBidPrice: initialBid,
            endAuction: endAuction,
            bidCount: 0,
            settled: false
        });
        allAuctions.push(newAuction);
        index++;

        emit NewAuction(
            newAuction.index,
            addressNFTCollection,
            addressPaymentToken,
            nftId,
            msg.sender,
            address(0),
            initialBid,
            endAuction,
            0
        );
        return newAuction.index;
    }

    function isOpen(uint256 auctionIndex) public view returns (bool) {
        return block.timestamp < allAuctions[auctionIndex].endAuction;
    }

    function getCurrentBidOwner(uint256 auctionIndex) public view returns (address) {
        require(auctionIndex < allAuctions.length, "Invalid auction index");
        return allAuctions[auctionIndex].currentBidOwner;
    }

    function getCurrentBid(uint256 auctionIndex) public view returns (uint256) {
        require(auctionIndex < allAuctions.length, "Invalid auction index");
        return allAuctions[auctionIndex].currentBidPrice;
    }

    function bid(uint256 auctionIndex, uint256 newBid) external returns (bool) {
        require(auctionIndex < allAuctions.length, "Invalid auction index");
        Auction storage auction = allAuctions[auctionIndex];
        require(isOpen(auctionIndex), "Auction is not open");
        require(newBid > auction.currentBidPrice, "New bid price must be higher than the current bid");
        require(msg.sender != auction.creator, "Creator of the auction cannot place new bid");

        ERC20 paymentToken = ERC20(auction.addressPaymentToken);
        require(paymentToken.transferFrom(msg.sender, address(this), newBid), "Tranfer of token failed");

        if (auction.bidCount > 0) {
            require(paymentToken.transfer(auction.currentBidOwner, auction.currentBidPrice));
        }

        auction.currentBidOwner = payable(msg.sender);
        auction.currentBidPrice = newBid;
        auction.bidCount++;
        emit NewBidOnAuction(auctionIndex, newBid);
        return true;
    }

    function claimNFT(uint256 auctionIndex) external {
        require(auctionIndex < allAuctions.length, "Invalid auction index");
        require(!isOpen(auctionIndex), "Auction is still open");

        Auction storage auction = allAuctions[auctionIndex];
        require(!auction.settled, "Auction already settled");
        require(auction.currentBidOwner == msg.sender, "NFT can be claimed only by the current bid owner");
        auction.settled = true;

        NFTCollection nftCollection = NFTCollection(auction.addressNFTCollection);
        require(nftCollection.transferNFTFrom(address(this), auction.currentBidOwner, auction.nftId));

        ERC20 paymentToken = ERC20(auction.addressPaymentToken);
        require(paymentToken.transfer(auction.creator, auction.currentBidPrice));
        emit NFTClaimed(auctionIndex, auction.nftId, msg.sender);
    }

    function claimToken(uint256 auctionIndex) external {
        require(auctionIndex < allAuctions.length, "Invalid auction index");
        require(!isOpen(auctionIndex), "Auction is still open");

        Auction storage auction = allAuctions[auctionIndex];
        require(auction.creator == msg.sender, "Tokens can be claimed only by the creator of the auction");
        require(!auction.settled, "Auction already settled");
        auction.settled = true;

        NFTCollection nftCollection = NFTCollection(auction.addressNFTCollection);
        require(nftCollection.transferNFTFrom(address(this), auction.currentBidOwner, auction.nftId));

        ERC20 paymentToken = ERC20(auction.addressPaymentToken);
        require(paymentToken.transfer(auction.creator, auction.currentBidPrice));
        emit TokensClaimed(auctionIndex, auction.nftId, msg.sender);
    }

    function refund(uint256 auctionIndex) external {
        require(auctionIndex < allAuctions.length, "Invalid auction index");
        require(!isOpen(auctionIndex), "Auction is still open");

        Auction storage auction = allAuctions[auctionIndex];
        require(auction.creator == msg.sender, "Tokens can be claimed only by the creator of the auction");
        require(auction.currentBidOwner == address(0), "Existing bider for this auction");
        require(!auction.settled, "Auction already settled");
        auction.settled = true;

        NFTCollection nftCollection = NFTCollection(auction.addressNFTCollection);
        require(nftCollection.transferNFTFrom(address(this), auction.creator, auction.nftId));
        emit NFTRefunded(auctionIndex, auction.nftId, msg.sender);
    }

    function onERC721Received(address, address, uint256, bytes memory)
        public
        pure
        override
        returns (bytes4)
    {
        return this.onERC721Received.selector;
    }
}
