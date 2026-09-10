// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./ERC20.sol";
import "./NFTCollection.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

/*
 * ┌───────────────────────────────────────────────────────────────────────────┐
 * │  QUESTION 1 - NFT MARKETPLACE AUCTION (MCQ fill-in lab)                    │
 * │                                                                            │
 * │  This file holds Checkpoints 2-4 (the marketplace itself). It builds on    │
 * │  the ERC-20 token (Checkpoint 0) and NFT collection (Checkpoint 1), so      │
 * │  solve those first. It implements an English-auction marketplace for       │
 * │  ERC-721 NFTs paid for in an ERC-20 token. The flow:                       │
 * │    1. A seller `createAuction`s an NFT (custody moves to this contract).   │
 * │    2. Buyers `bid` with ERC-20 tokens (escrowed here; prior bidder         │
 * │       refunded).                                                           │
 * │    3. After the deadline, the winner `claimNFT` (creator gets paid) or     │
 * │       the creator `claimToken` / `refund` (no bids) settles the auction.   │
 * │                                                                            │
 * │  Twelve decisions (Q9–Q20) are left blank. Each has options A / B / C,     │
 * │  all commented out, each with a plain-English note. UNCOMMENT EXACTLY ONE  │
 * │  per question (delete the leading "// "). Some options compile and pass;   │
 * │  others compile but FAIL the tests. The correct answer's position          │
 * │  carries NO signal.                                                        │
 * │                                                                            │
 * │  Test as you go:                                                           │
 * │    forge test --mc Checkpoint2   # Q9–Q11  (createAuction)                 │
 * │    forge test --mc Checkpoint3   # Q12–Q15  (bid)                          │
 * │    forge test --mc Checkpoint4   # Q16–Q20 (claimNFT / refund)             │
 * └───────────────────────────────────────────────────────────────────────────┘
 */
// Why `is IERC721Receiver`? When an NFT is sent to a CONTRACT with
// `safeTransferFrom` (as our escrow transfer in Q11 does), the ERC-721
// standard calls `onERC721Received` on the destination and requires it to
// return a specific magic value. This is a safety handshake: a contract that
// doesn't implement the hook is assumed unable to ever send the NFT back out,
// so the transfer reverts rather than locking the token forever. By declaring
// `is IERC721Receiver` and implementing the hook (bottom of this file), the
// marketplace says: "I know how to hold NFTs — safe transfers to me are OK."
contract Marketplace is IERC721Receiver {
    string public name;
    uint256 public index = 0;

    struct Auction {
        uint256 index; // Auction index
        address addressNFTCollection; // ERC-721 collection contract
        address addressPaymentToken; // ERC-20 payment token contract
        uint256 nftId; // NFT token id under auction
        address creator; // Seller who opened the auction
        address payable currentBidOwner; // Highest bidder
        uint256 currentBidPrice; // Highest bid amount
        uint256 endAuction; // Unix timestamp when the auction closes
        uint256 bidCount; // Number of bids placed
        bool settled; // Set the moment the auction pays out — blocks double settlement
    }

    Auction[] private allAuctions;


    // Lifecycle events. Each one writes an entry to the transaction log (see
    // Q4 in ERC20.sol) at a decision point an off-chain observer cares about:
    //   • NewAuction      — a listing appeared: front-ends add it to the board.
    //   • NewBidOnAuction — the price moved: UIs update, out-bid users notify.
    //   • NFTClaimed / TokensClaimed / NFTRefunded — the auction settled one of
    //     the three possible ways, so indexers can mark it closed.
    // Contracts cannot read these logs back — they exist purely so wallets,
    // indexers, and UIs can follow the marketplace without polling storage.
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

    constructor(string memory _name) {
        name = _name;
    }

    // Returns true if `_addr` is a contract (has bytecode), false for an EOA.
    function isContract(address _addr) private view returns (bool) {
        uint256 size;
        // `extcodesize(addr)` is a raw EVM opcode: the size, in bytes, of the
        // code deployed at an address. EOAs have no code (size 0); contracts
        // have their bytecode (size > 0). Solidity (pre-0.8.1) exposed no
        // high-level way to ask this, so we drop into an `assembly` block,
        // which lets us invoke EVM opcodes directly. (Caveat worth knowing:
        // a contract's constructor runs BEFORE its code is stored, so code
        // calling us from its constructor also reads as size 0 — this check
        // screens out obvious mistakes, it is not a security boundary.)
        assembly {
            size := extcodesize(_addr)
        }
        return size > 0;
    }

    // ════════════════════════════════════════════════════════════════════════
    //  CHECKPOINT 2 — createAuction  (Q9, Q10, Q11)
    // ════════════════════════════════════════════════════════════════════════
    function createAuction(
        address _addressNFTCollection,
        address _addressPaymentToken,
        uint256 _nftId,
        uint256 _initialBid,
        uint256 _endAuction
    ) external returns (uint256) {
        // Basic argument validation (given — these are not MCQ blanks):
        require(isContract(_addressNFTCollection), "Invalid NFT Collection contract address");
        require(isContract(_addressPaymentToken), "Invalid Payment Token contract address");
        require(_endAuction > block.timestamp, "Invalid end date for auction");
        require(_initialBid > 0, "Invalid initial bid price");

        NFTCollection nftCollection = NFTCollection(_addressNFTCollection);

        /* ─── Q9: only the NFT's owner may auction it. Which check? ───────────
           Background: `ownerOf(id)` returns the token's current owner.
             • msg.sender = the address that directly called createAuction.
             • tx.origin  = the original EOA that started the transaction.
           A) require the on-chain OWNER equals the direct caller (msg.sender).
           B) require the OWNER equals tx.origin instead. Usually behaves the
              same, but consider the owner being tricked into calling a
              malicious contract that then calls us on their behalf.
           C) no check at all — anyone could auction someone else's NFT.
           UNCOMMENT EXACTLY ONE: */
        // require(nftCollection.ownerOf(_nftId) == msg.sender, "Caller is not the owner of the NFT");
        // require(nftCollection.ownerOf(_nftId) == tx.origin, "Caller is not the owner of the NFT");
        // (option C: leave all commented — no ownership check)

        /* ─── Q10: the Marketplace must be approved to move this NFT. Which? ──
           Background: `getApproved(id)` returns the single address the owner
           approved to transfer that specific token. Ask yourself: WHO is about
           to take custody of the NFT in the next step?
           A) require getApproved(_nftId) == address(this)  — demands that the
              approved operator is the marketplace contract itself.
           B) require getApproved(_nftId) == msg.sender  — demands that the
              approved operator is the seller, i.e. asks whether the owner
              approved themselves.
           C) no check — rely on the transfer reverting later with a worse error.
           UNCOMMENT EXACTLY ONE: */
        // require(nftCollection.getApproved(_nftId) == address(this), "Require NFT ownership transfer approval");
        // require(nftCollection.getApproved(_nftId) == msg.sender, "Require NFT ownership transfer approval");
        // (option C: leave all commented — no approval check)

        /* ─── Q11: lock the NFT by moving custody into the marketplace. ───────
           Background: transferNFTFrom(from, to, id) moves the NFT between the
           two addresses. Escrow means: the marketplace holds the item while
           the auction runs. Mind the direction of each option.
           A) nftCollection.approve(address(this), _nftId) — records an
              approval; custody of the token does not change.
           B) transferNFTFrom(address(this), msg.sender, _nftId) — moves the
              token from the marketplace to the seller.
           C) transferNFTFrom(msg.sender, address(this), _nftId) — moves the
              token from the seller to the marketplace.
           UNCOMMENT EXACTLY ONE: */
        // nftCollection.approve(address(this), _nftId);
        // require(nftCollection.transferNFTFrom(address(this), msg.sender, _nftId));
        // require(nftCollection.transferNFTFrom(msg.sender, address(this), _nftId));

        // Build and store the auction (given):
        address payable currentBidOwner = payable(address(0));
        Auction memory newAuction = Auction({
            index: index,
            addressNFTCollection: _addressNFTCollection,
            addressPaymentToken: _addressPaymentToken,
            nftId: _nftId,
            creator: msg.sender,
            currentBidOwner: currentBidOwner,
            currentBidPrice: _initialBid,
            endAuction: _endAuction,
            bidCount: 0,
            settled: false
        });
        allAuctions.push(newAuction);
        index++;

        // Announce and return THIS auction's index (`index` itself has already
        // moved on to the next auction).
        emit NewAuction(
            newAuction.index,
            _addressNFTCollection,
            _addressPaymentToken,
            _nftId,
            msg.sender,
            currentBidOwner,
            _initialBid,
            _endAuction,
            0
        );
        return newAuction.index;
    }

    // An auction is open while the current time is before its end timestamp.
    function isOpen(uint256 _auctionIndex) public view returns (bool) {
        Auction storage auction = allAuctions[_auctionIndex];
        if (block.timestamp >= auction.endAuction) return false;
        return true;
    }

    function getCurrentBidOwner(uint256 _auctionIndex) public view returns (address) {
        require(_auctionIndex < allAuctions.length, "Invalid auction index");
        return allAuctions[_auctionIndex].currentBidOwner;
    }

    function getCurrentBid(uint256 _auctionIndex) public view returns (uint256) {
        require(_auctionIndex < allAuctions.length, "Invalid auction index");
        return allAuctions[_auctionIndex].currentBidPrice;
    }

    // ════════════════════════════════════════════════════════════════════════
    //  CHECKPOINT 3 — bid  (Q12, Q13, Q14, Q15)
    // ════════════════════════════════════════════════════════════════════════
    function bid(uint256 _auctionIndex, uint256 _newBid) external returns (bool) {
        require(_auctionIndex < allAuctions.length, "Invalid auction index");
        Auction storage auction = allAuctions[_auctionIndex];
  
        require(isOpen(_auctionIndex), "Auction is not open");

        /* ─── Q12: a new bid must beat the standing price. Which comparison? ──
           currentBidPrice starts at the seller's initial price and rises with
           each bid. Think about what should happen to a bid that exactly TIES
           the standing price.
           A) _newBid > currentBidPrice  — strictly higher: a tie is rejected,
              and the very first bid must exceed the starting price.
           B) _newBid >= currentBidPrice  — a bidder can take the lead by
              merely matching the standing price (or the starting price).
           C) _newBid > 0  — accepts any positive number, ignoring the current
              price entirely.
           UNCOMMENT EXACTLY ONE: */
        // require(_newBid > auction.currentBidPrice, "New bid price must be higher than the current bid");
        // require(_newBid >= auction.currentBidPrice, "New bid price must be higher than the current bid");
        // require(_newBid > 0, "New bid price must be higher than the current bid");

        /* ─── Q13: the seller must not bid on their own auction. Which guard? ──
           A) require(msg.sender != auction.creator)  — rejects the call when
              the bidder IS the creator.
           B) require(msg.sender == auction.creator)  — rejects the call when
              the bidder is NOT the creator.
           C) no guard — the creator can shill-bid their own auction to drive
              the price up.
           UNCOMMENT EXACTLY ONE: */
        // require(msg.sender != auction.creator, "Creator of the auction cannot place new bid");
        // require(msg.sender == auction.creator, "Creator of the auction cannot place new bid");
        // (option C: leave all commented — no self-bid guard)

        ERC20 paymentToken = ERC20(auction.addressPaymentToken);

        /* ─── Q14: escrow the bidder's tokens into the marketplace. Which? ─────
           Background: transfer(to, amt) moves tokens FROM msg.sender — and
           inside this function, msg.sender of the token call is the
           MARKETPLACE itself. transferFrom(from, to, amt) moves tokens from
           `from`, consuming an allowance. Track carefully whose tokens each
           option moves, and in which direction.
           A) transferFrom(address(this), msg.sender, _newBid) — moves tokens
              from the marketplace to the bidder.
           B) transferFrom(msg.sender, address(this), _newBid) — moves tokens
              from the bidder to the marketplace, using the allowance the
              bidder granted beforehand.
           C) transfer(address(this), _newBid) — the marketplace moves its OWN
              tokens to itself; the bidder is never charged.
           UNCOMMENT EXACTLY ONE: */
        // require(paymentToken.transferFrom(address(this), msg.sender, _newBid), "Tranfer of token failed");
        // require(paymentToken.transferFrom(msg.sender, address(this), _newBid), "Tranfer of token failed");
        // require(paymentToken.transfer(address(this), _newBid), "Tranfer of token failed");

        /* ─── Q15: refund the PREVIOUS highest bidder their escrowed tokens. ───
           This runs BEFORE we overwrite currentBidOwner/currentBidPrice below,
           so those fields still describe the bidder being out-bid. Only refund
           if there actually was a prior bidder (bidCount > 0). How much did
           that bidder actually lock up?
           A) refund currentBidOwner the _newBid amount — the incoming (higher)
              number.
           B) refund currentBidOwner exactly their currentBidPrice — the amount
              that bidder escrowed when they took the lead.
           C) skip the refund — the out-bid bidder's tokens remain in the
              marketplace with no code path returning them.
           UNCOMMENT EXACTLY ONE (A and B are an if-block; uncomment all 3 lines
           of the one you choose): */
        // if (auction.bidCount > 0) {
        //     paymentToken.transfer(auction.currentBidOwner, _newBid);
        // }
        // if (auction.bidCount > 0) {
        //     paymentToken.transfer(auction.currentBidOwner, auction.currentBidPrice);
        // }
        // (option C: leave all commented — no refund of the prior bidder)

        // Record the new winning bid (given):
        address payable newBidOwner = payable(msg.sender);
        auction.currentBidOwner = newBidOwner;
        auction.currentBidPrice = _newBid;
        auction.bidCount++;

        emit NewBidOnAuction(_auctionIndex, _newBid);
        return true;
    }

    // ════════════════════════════════════════════════════════════════════════
    //  CHECKPOINT 4 — claimNFT / refund  (Q16, Q17, Q18, Q19, Q20)
    // ════════════════════════════════════════════════════════════════════════

    // Winner withdraws the NFT; this also pays the seller their tokens.
    function claimNFT(uint256 _auctionIndex) external {
        require(_auctionIndex < allAuctions.length, "Invalid auction index");

        /* ─── Q16: claiming is only allowed once the auction has CLOSED. ───────
           isOpen(i) is true while the auction is still running.
           A) require(!isOpen(_auctionIndex))  — the call proceeds only after
              the deadline has passed.
           B) require(isOpen(_auctionIndex))   — the call proceeds only while
              bidding is still running.
           C) no check — claim at any time, even mid-auction.
           UNCOMMENT EXACTLY ONE: */
        // require(!isOpen(_auctionIndex), "Auction is still open");
        // require(isOpen(_auctionIndex), "Auction is still open");
        // (option C: leave all commented — no open/closed check)

        Auction storage auction = allAuctions[_auctionIndex];

        // Given: an auction settles exactly ONCE — through claimNFT, claimToken
        // OR refund, whichever runs first. The flag flips BEFORE any assets
        // move (effects before interactions). Same pattern as the HTLC lab's
        // `settled` flag.
        require(!auction.settled, "Auction already settled");

        /* ─── Q17: only the winning bidder may claim the NFT. Which check? ─────
           A) require(auction.creator == msg.sender)  — admits the seller.
           B) require(auction.currentBidOwner == msg.sender)  — admits the
              highest bidder.
           C) no check — anyone may call and trigger the NFT hand-off.
           UNCOMMENT EXACTLY ONE: */
        // require(auction.creator == msg.sender, "NFT can be claimed only by the current bid owner");
        // require(auction.currentBidOwner == msg.sender, "NFT can be claimed only by the current bid owner");
        // (option C: leave all commented — no winner check)

        auction.settled = true; // given — see the note above Q17

        NFTCollection nftCollection = NFTCollection(auction.addressNFTCollection);

        /* ─── Q18: send the NFT from escrow to the winner. Mind the token id! ─
           The auction's array INDEX and the NFT's token id are different
           numbers — an auction at index 0 can perfectly well be selling token
           id 7. Check both the direction and WHICH number identifies the token.
           A) transferNFTFrom(address(this), currentBidOwner, _auctionIndex)
              — passes the auction's array index in the token-id slot. (The
              upstream open-source repo this lab is adapted from shipped with
              exactly this line.)
           B) transferNFTFrom(currentBidOwner, address(this), auction.nftId)
              — moves the escrowed token from the winner to the marketplace.
           C) transferNFTFrom(address(this), currentBidOwner, auction.nftId)
              — moves the escrowed token from the marketplace to the winner.
           UNCOMMENT EXACTLY ONE: */
        // require(nftCollection.transferNFTFrom(address(this), auction.currentBidOwner, _auctionIndex));
        // require(nftCollection.transferNFTFrom(auction.currentBidOwner, address(this), auction.nftId));
        // require(nftCollection.transferNFTFrom(address(this), auction.currentBidOwner, auction.nftId));

        ERC20 paymentToken = ERC20(auction.addressPaymentToken);

        /* ─── Q19: pay the escrowed tokens out. To whom, and how much? ────────
           The winner's tokens are sitting in escrow, and the winner has just
           received the NFT. Who is still owed something?
           A) transfer(auction.creator, auction.currentBidPrice) — sends the
              winning bid amount to the seller.
           B) transfer(auction.currentBidOwner, auction.currentBidPrice) —
              sends the winning bid amount back to the winner, who then holds
              BOTH the NFT and their money.
           C) skip — nobody is paid; the winning bid stays in the marketplace
              with no code path releasing it.
           UNCOMMENT EXACTLY ONE: */
        // require(paymentToken.transfer(auction.creator, auction.currentBidPrice));
        // require(paymentToken.transfer(auction.currentBidOwner, auction.currentBidPrice));
        // (option C: leave all commented — seller is not paid)

        emit NFTClaimed(_auctionIndex, auction.nftId, msg.sender);
    }

    // Seller withdraws their tokens after a successful auction; this delivers
    // the NFT to the winner. (Given — fully implemented, no blanks.)
    function claimToken(uint256 _auctionIndex) external {
        require(_auctionIndex < allAuctions.length, "Invalid auction index");
        require(!isOpen(_auctionIndex), "Auction is still open");

        Auction storage auction = allAuctions[_auctionIndex];
        require(auction.creator == msg.sender, "Tokens can be claimed only by the creator of the auction");
        require(!auction.settled, "Auction already settled");
        auction.settled = true;

        NFTCollection nftCollection = NFTCollection(auction.addressNFTCollection);
        require(nftCollection.transferNFTFrom(address(this), auction.currentBidOwner, auction.nftId));

        ERC20 paymentToken = ERC20(auction.addressPaymentToken);
        paymentToken.transfer(auction.creator, auction.currentBidPrice);

        emit TokensClaimed(_auctionIndex, auction.nftId, msg.sender);
    }

    // Seller reclaims the NFT when the auction closed with NO bids.
    function refund(uint256 _auctionIndex) external {
        require(_auctionIndex < allAuctions.length, "Invalid auction index");
        require(!isOpen(_auctionIndex), "Auction is still open");

        Auction storage auction = allAuctions[_auctionIndex];
        require(auction.creator == msg.sender, "Tokens can be claimed only by the creator of the auction");

        /* ─── Q20: refund is only legitimate when NOBODY bid. Which guard? ────
           A no-bid auction still has currentBidOwner == address(0), the value
           it was initialized with. Consider what each guard means for an
           auction that DID receive a winning bid.
           A) require(auction.currentBidOwner != address(0))  — permits the
              refund exactly when a winning bidder exists.
           B) require(auction.currentBidOwner == address(0))  — permits the
              refund exactly when no one ever bid.
           C) no check — the seller can always pull the NFT back, including
              after someone won it.
           UNCOMMENT EXACTLY ONE: */
        // require(auction.currentBidOwner != address(0), "Existing bider for this auction");
        // require(auction.currentBidOwner == address(0), "Existing bider for this auction");
        // (option C: leave all commented — no "no bids" guard)

        require(!auction.settled, "Auction already settled"); // given
        auction.settled = true;

        NFTCollection nftCollection = NFTCollection(auction.addressNFTCollection);
        require(nftCollection.transferNFTFrom(address(this), auction.creator, auction.nftId));

        emit NFTRefunded(_auctionIndex, auction.nftId, msg.sender);
    }

    // The IERC721Receiver hook (see the note above the contract declaration).
    // ERC-721's safeTransferFrom calls this on any contract recipient and
    // aborts the transfer unless it returns this exact selector — our way of
    // acknowledging "yes, I intentionally accept NFTs".
    function onERC721Received(address, address, uint256, bytes memory)
        public
        virtual
        override
        returns (bytes4)
    {
        return this.onERC721Received.selector;
    }
}
