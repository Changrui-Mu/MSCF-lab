// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/*
 * ┌───────────────────────────────────────────────────────────────────────────┐
 * │  QUESTION 1 / CHECKPOINT 1 - ERC-721 NFT COLLECTION  (Q7-Q8)               │
 * │                                                                            │
 * │  NFTs minted here are the items put up for auction. The marketplace moves  │
 * │  custody of an NFT via `transferNFTFrom`, so both functions must behave.   │
 * │  UNCOMMENT EXACTLY ONE option (A/B/C) per question. The correct answer's   │
 * │  position carries NO signal.                                               │
 * │                                                                            │
 * │    forge test --mc Checkpoint1      # this file (Q7-Q8)                    │
 * └───────────────────────────────────────────────────────────────────────────┘
 *
 * ─── What do we inherit from `is ERC721`? ────────────────────────────────────
 * Unlike our hand-rolled ERC20, here the whole EIP-721 standard machinery is
 * INHERITED from OpenZeppelin's audited implementation. That means this file
 * only writes what is SPECIFIC to our collection (minting and the marketplace's
 * transfer wrapper); everything below comes for free from the base contract:
 *   • ownerOf(id)            — who currently owns a token
 *   • balanceOf(addr)        — how many tokens an address holds
 *   • approve(to, id) / getApproved(id)        — per-token operator approval
 *   • setApprovalForAll / isApprovedForAll      — collection-wide approval
 *   • transferFrom / safeTransferFrom           — custody transfers (with
 *     authorization checks against the approvals above)
 *   • name() / symbol()      — set once via the constructor below
 *   • Transfer / Approval / ApprovalForAll events
 * The marketplace calls several of these directly (ownerOf, getApproved) —
 * we never re-implement them.
 */

contract NFTCollection is ERC721 {
    struct NFT {
        string name;
        string URI;
    }

    // Event announcing that a new token was minted, and by whom. Like the
    // ERC-20 Transfer event (Q4), this writes an entry to the transaction log
    // so off-chain software — a gallery UI, an indexer, the auction front-end —
    // can list new NFTs without polling the contract. `indexed` makes the
    // minter address searchable ("show all NFTs minted by Alice").
    event Mint(uint256 index, address indexed mintedBy);

    NFT[] private allNFTs;

    constructor() ERC721("NFT Collection", "NFTC") {}

    // Mint a new NFT for sale. Returns the new token id.
    // Deliberately permissionless: this collection is an open gallery where any
    // seller mints their OWN new token — there is nothing here to steal. (A
    // curated collection would add an owner/role check; that is a policy
    // choice, not a security hole.)
    function mintNFT(string memory _nftName, string memory _nftURI) external returns (uint256) {
        allNFTs.push(NFT({name: _nftName, URI: _nftURI}));
        uint256 tokenId = allNFTs.length - 1;

        /* ─── Q7: who should receive the freshly minted NFT? ──────────────────
           Background: `_safeMint(to, id)` is OpenZeppelin's internal mint. The
           person calling mintNFT (the seller) should own the new NFT.
             • msg.sender    = the direct caller of mintNFT.
             • tx.origin     = the original EOA of the transaction.
             • address(this) = this collection contract itself.
           A) _safeMint(tx.origin, tokenId);   — mint to the original EOA, which
              is usually the same as msg.sender but differs when mintNFT is
              called through another contract.
           B) _safeMint(address(this), tokenId); — the collection mints to
              itself, so the seller never owns anything they can auction.
           C) _safeMint(msg.sender, tokenId);  — mint to the direct caller.
           UNCOMMENT EXACTLY ONE: */
        // _safeMint(tx.origin, tokenId);
        // _safeMint(address(this), tokenId);
        // _safeMint(msg.sender, tokenId);

        emit Mint(tokenId, msg.sender);
        return tokenId;
    }

    // Wrapper the marketplace uses to move an NFT into / out of escrow.
    //
    // WHERE IS THE AUTHORIZATION CHECK? Not in this file — and yet a stranger
    // calling transferNFTFrom(victim, attacker, id) is rejected. The inherited
    // OpenZeppelin safeTransferFrom (the call below) checks that the caller of
    // THIS function (msg.sender) is the token's owner or an approved operator,
    // and reverts otherwise. Two lessons: (1) "no check visible" is not the
    // same as "no check" — guards can live in an inherited layer, just like
    // transaction signatures are verified by the protocol before your code
    // ever runs; (2) when auditing, an invisible inherited guard is something
    // you must VERIFY exists, never assume.
    function transferNFTFrom(address from, address to, uint256 tokenId) public virtual returns (bool) {
        /* ─── Q8: actually move the NFT from `from` to `to`. ──────────────────
           A) safeTransferFrom(to, from, tokenId);  — moves the token from `to`
              to `from`.
           B) safeTransferFrom(from, to, tokenId);  — moves the token from
              `from` to `to` (and runs the receiver's onERC721Received hook if
              the destination is a contract).
           C) _safeMint(to, tokenId);  — creates a NEW token with this id
              instead of moving the existing one.
           UNCOMMENT EXACTLY ONE: */
        // safeTransferFrom(to, from, tokenId);
        // safeTransferFrom(from, to, tokenId);
        // _safeMint(to, tokenId);

        return true;
    }
}
