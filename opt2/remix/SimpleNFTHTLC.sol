// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts@5.4.0/token/ERC721/IERC721.sol";

/*
 * ┌─────────────────────────────────────────────────────────────────────────┐
 * │ QUESTION 2 - SimpleNFTHTLC: hand over the goods for a secret            │
 * │                                                                         │
 * │ Every blank is multiple choice: options A/B/C (sometimes D), each with  │
 * │ a note on what it does and how it differs. Uncomment EXACTLY ONE per    │
 * │ question. The correct answer's position carries NO signal.              │
 * │                                                                         │
 * │ Check your work: deploy SimpleNFTHTLCChecker, attach 1 wei, call        │
 * │ runAllTests — a revert names the question to fix (see README.md).       │
 * └─────────────────────────────────────────────────────────────────────────┘
 *
 * ─── The story: Alice sells her NFT to Bob ─────────────────────────────────
 *
 * In the SimpleHTLC lab you built the ETH contract for a fair exchange. It
 * locks ETH under the sha256 hash of a secret. This is the NFT contract. It
 * uses the same hash and deadline pattern, but locks an NFT:
 *
 *   • Alice locks the NFT here, under hash `h`, with buyer Bob as receiver.
 *   • Bob locks his ETH in a SimpleHTLC (the contract you already
 *     built!) under the SAME hash `h`, with Alice as receiver.
 *   • Alice withdraws Bob's ETH — which forces her to reveal the secret
 *     on-chain. Bob replays that same secret here and withdraws the NFT.
 *   • If either side walks away, both locks expire and everyone refunds.
 *
 * In the real exchange, the two contracts are on two different chains. They
 * do not call each other. One secret opens both boxes, which makes the sale
 * atomic. The checker runs the full two-contract sale in one test environment.
 *
 * ─── What's genuinely NEW compared to SimpleHTLC ───────────────────────────
 *
 * ETH could ride along with the deploy transaction (`payable` constructor).
 * An NFT cannot — a token is a ledger entry inside the NFT contract, so the
 * only way to move it here is to ASK the NFT contract to update that entry.
 * Locking therefore takes two steps: Alice first `approve`s this contract
 * on the NFT, then calls lock(), which pulls the token in. Q1 and Q2 are
 * about exactly this difference; everything else you have seen before.
 */
contract SimpleNFTHTLC {
    address public sender;   // Alice — the seller who locks the NFT
    address public receiver; // Bob — the only address the NFT can go to
    IERC721 public nft;      // the NFT contract (the ledger holding the token)
    uint256 public tokenId;  // which token is being sold
    bytes32 public hashlock; // sha256 hash of the secret
    uint256 public deadline; // after this, Alice may take the NFT back
    bool    public locked;   // the NFT was moved in by lock()
    bool    public settled;  // the NFT has left — forever

    constructor(address _nft, uint256 _tokenId, address _receiver, bytes32 _hashlock, uint256 _deadline) {
        sender = msg.sender; // same decision you made in SimpleHTLC
        nft = IERC721(_nft);
        tokenId = _tokenId;
        receiver = _receiver;
        hashlock = _hashlock;
        deadline = _deadline;
    }

    /// Step 2 of locking. Alice calls this AFTER approving this contract on
    /// the NFT (step 1 happens in the Remix UI: nft.approve(<this>, tokenId)).
    function lock() external {
        require(msg.sender == sender, "not the sender");
        require(!locked, "already locked");
        locked = true;

        /* ─── Q1: move the NFT into this contract. ─────────────────────
           Remember: the token is an entry in the NFT contract's ledger, not
           an object that can be "sent along" with a call.
           A) (do nothing) — wait for the NFT to arrive by itself, the way
              the ETH arrived in SimpleHTLC's payable constructor. But a
              ledger entry never moves unless the NFT contract is asked to
              move it — the NFT never arrives.
           B) nft.approve(address(this), tokenId);
              This contract grants ITSELF permission — but approvals are
              granted by the token's owner (Alice), and this contract is not
              the owner. The NFT contract rejects the call.
           C) nft.transferFrom(sender, address(this), tokenId);
              Pulls the token from Alice into this contract, using the
              approval Alice granted in step 1. The NFT moves here.
           Uncomment EXACTLY ONE (for option A, leave all lines commented): */
        // nft.approve(address(this), tokenId);
        // nft.transferFrom(sender, address(this), tokenId);
    }

    /// Bob (or anyone!) calls this with the secret to send the NFT to Bob.
    function withdraw(bytes32 secret) external {
        /* ─── Q2: the NFT must actually be in this contract. ────────────
           This guard did not exist in SimpleHTLC — its payable constructor
           received the ETH as the contract was created. Here lock() is a
           separate call, so a new contract holds nothing yet.
           A) require(locked, "not locked");
              Rejects withdrawal until lock() has actually pulled the NFT in.
           B) require(!locked, "not locked");
              Inverted: allows withdrawal ONLY BEFORE the NFT arrives — once it
              is actually here, nobody can ever claim it.
           C) (no check — assume Alice always remembers to lock)
              A withdraw on an empty contract then reverts deep inside the
              NFT transfer with a confusing error — or worse, "succeeds"
              partially if later questions are also wrong.
           Uncomment EXACTLY ONE: */
        // require(locked, "not locked");
        // require(!locked, "not locked");
        // (option C: leave all commented — no locked check)

        /* ─── Q3: the NFT must not have left already. ───────────────────
           A) require(settled, "already settled");
              Inverted: only allows withdrawal AFTER settlement — so the
              first, legitimate claim is always rejected.
           B) require(!settled, "already settled");
              The one-shot guard: once the NFT has left, every later call
              stops here, loudly.
           C) (no check)
              Relies on the NFT transfer at the bottom failing by accident —
              the revert reason a caller sees is then an OpenZeppelin
              internal error, not your message.
           Uncomment EXACTLY ONE: */
        // require(settled, "already settled");
        // require(!settled, "already settled");
        // (option C: leave all commented — no one-shot guard)

        /* ─── Q4: claiming is only allowed BEFORE the deadline. ─────────
           A) require(block.timestamp >= deadline, "too late");
              Inverted: Bob may only claim AFTER the deadline — exactly the
              window in which Alice may also refund. The two paths now race.
           B) (no check — the secret works forever)
              Alice can never safely refund: even years later, a revealed
              secret would still unlock the NFT.
           C) require(block.timestamp < deadline, "too late");
              Bob's claiming window closes exactly where Alice's refund
              window opens — the two can never overlap.
           Uncomment EXACTLY ONE: */
        // require(block.timestamp >= deadline, "too late");
        // require(block.timestamp < deadline, "too late");
        // (option B: leave all commented — no deadline check)

        /* ─── Q5: check the secret. ─────────────────────────────────────
           The contract only knows the HASH of the secret, never the secret.
           A) require(secret == hashlock, "wrong secret");
              Compares the secret directly to the hash — those are different
              values by construction, so the true secret is always rejected.
           B) require(sha256(abi.encodePacked(hashlock)) == secret, "wrong secret");
              Hashes the stored hash — the contract cannot conjure the
              secret out of the hash, in either direction.
           C) require(sha256(abi.encodePacked(secret)) == hashlock, "wrong secret");
              Recomputes the hash of the submitted secret and compares
              hashes — the only check the contract can actually perform.
           Uncomment EXACTLY ONE: */
        // require(secret == hashlock, "wrong secret");
        // require(sha256(abi.encodePacked(hashlock)) == secret, "wrong secret");
        // require(sha256(abi.encodePacked(secret)) == hashlock, "wrong secret");

        /* ─── Q6: record the settlement — BEFORE the token moves. ───────
           A) settled = true;
              Flips the one-shot flag first, then the transfer happens:
              effects before interactions, same as SimpleHTLC.
           B) locked = false;
              "Un-locks" instead of settling: the settled flag Q3 checks
              never flips, and the contract pretends it was never locked.
           C) (skip — the NFT leaving IS the record)
              Ownership does change, but Q3's guard reads `settled`, which
              stays false — the contract's own bookkeeping is now wrong.
           Uncomment EXACTLY ONE: */
        // settled = true;
        // locked = false;
        // (option C: leave all commented — nothing recorded)

        /* ─── Q7: deliver the NFT. ──────────────────────────────────────
           Note that ANYONE may have called this function, not just Bob.
           A) nft.approve(receiver, tokenId);
              Only grants Bob the RIGHT to come take the token later —
              the NFT stays in this contract, and ownerOf still says so.
           B) nft.safeTransferFrom(address(this), msg.sender, tokenId);
              Hands the token to whoever submitted the correct secret — the
              mempool front-running trap you already met in SimpleHTLC, now
              with a unique item instead of ETH.
           C) nft.safeTransferFrom(address(this), receiver, tokenId);
              Hands the token to the receiver chosen when this was created,
              who called — the secret is a key, not an identity.
           Uncomment EXACTLY ONE: */
        // nft.approve(receiver, tokenId);
        // nft.safeTransferFrom(address(this), msg.sender, tokenId);
        // nft.safeTransferFrom(address(this), receiver, tokenId);
    }

    /// Alice takes the NFT back if Bob never claimed in time.
    function refund() external {
        require(msg.sender == sender, "not the sender");
        require(locked, "not locked");
        require(block.timestamp >= deadline, "too early");

        /* ─── Q8: refund must also be one-shot. ─────────────────────────
           A) require(!settled, "already settled");
              settled = true;
              Guard, then record — a second refund (or a refund after a
              claim) stops loudly at the guard.
           B) require(!settled, "already settled");
              Guard but never record — this refund does not flip the flag,
              so the contract never remembers it happened.
           C) settled = true;
              Record but never guard — a second refund walks straight into
              the NFT transfer and dies there with an internal error.
           D) (skip both)
              No guard, no record.
           Uncomment EXACTLY ONE (option A is TWO lines — uncomment both): */
        // require(!settled, "already settled");
        // settled = true;
        // (option D: leave all commented)

        nft.safeTransferFrom(address(this), sender, tokenId);
    }

    // A note on what is NOT here: SimpleNFTHTLC has no onERC721Received hook,
    // so a `safeTransferFrom` aimed AT this contract is rejected. That is on
    // purpose — the only door in is lock()'s pull, so no NFT can ever be
    // stranded here by accident.
}

/* ═══════════════════════════════════════════════════════════════════════════
   BEFORE YOU MOVE ON — self-check
   ───────────────────────────────────────────────────────────────────────────
   Question index for this file:
     Q1  lock      — how does the contract move the NFT in?
     Q2  withdraw  — how do we know the NFT was actually moved in?
     Q3  withdraw  — how is a second payout blocked?
     Q4  withdraw  — when does Bob's claiming window close?
     Q5  withdraw  — how is the secret checked?
     Q6  withdraw  — what gets recorded before the token moves?
     Q7  withdraw  — who receives the NFT?
     Q8  refund    — how is refund kept one-shot?

   For EACH question, confirm you uncommented EXACTLY ONE option (for a
   "do nothing" option, all lines stay commented — that IS your answer).
   A skipped question still compiles: compiling is not the answer key.

   Checking your work (all in Remix — see README.md):
   first complete Part A in SimpleHTLC.sol in this same folder, then compile
   all five files (compiler 0.8.20+), deploy SimpleNFTHTLCChecker, attach
   1 wei, runAllTests, then isSolved() → true.

   NOTE for Q8's B/C/D: the "wrong" behaviors there are partly masked by the
   NFT itself — a unique token can only leave once, so a second transfer
   reverts anyway. The checker therefore checks WHICH error a second refund
   produces: your "already settled", or an OpenZeppelin internal error.
   Ask yourself why explicit flags still matter when ownership already acts
   as an accidental one. (Good oral-exam material.)
   ═══════════════════════════════════════════════════════════════════════════ */
