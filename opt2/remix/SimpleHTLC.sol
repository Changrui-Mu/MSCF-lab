// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * Question 2, Part A - SimpleHTLC: "pay for a secret"
 * ===================================================
 * Alice wants to buy a secret password from Bob, but neither trusts the other.
 * Alice won't pay first (Bob might vanish); Bob won't tell first (Alice might
 * not pay). This contract locks the ETH and makes the trade fair:
 *
 *   1. Alice creates it with ETH and the sha256 HASH of
 *      the secret she expects. The money is now locked.
 *   2. Bob claims the money by calling withdraw(secret). The contract checks
 *      the secret against the hash — by claiming, Bob necessarily reveals the
 *      secret to Alice (and the whole world) on-chain.
 *   3. If Bob never shows up, Alice calls refund() after the deadline and
 *      takes her money back. Nobody's funds can get stuck forever.
 *
 * YOUR JOB — complete the six marked TODOs. Two kinds:
 *   [WRITE]  — write the line yourself; the hint says exactly what it must do.
 *   [CHOOSE] — uncomment exactly ONE of the A / B / C lines.
 *              (The correct answer is not always A.)
 *
 * When you are done, deploy SimpleHTLCChecker.sol and follow README.md to
 * check your work. Wrong choices make the checker's transaction revert.
 */
contract SimpleHTLC {
    address public sender;   // Alice — the party who locks the money
    address public receiver; // Bob — the only address the money can be paid to
    bytes32 public hashlock; // sha256 hash of the secret (the secret itself is NOT stored!)
    uint256 public deadline; // after this unix time, Alice may take her money back
    bool    public settled;  // flips to true the moment the money leaves — forever

    /// Alice creates the contract with ETH attached as msg.value.
    constructor(address _receiver, bytes32 _hashlock, uint256 _deadline) payable {
        // ------------------------------------------------------------------
        // TODO 1 [CHOOSE] — who should be recorded as `sender`, the party
        // allowed to reclaim the money after the deadline?
        // Uncomment exactly ONE:
        //
        // sender = _receiver;      // A: the receiver — but Bob never deposited anything
        // sender = msg.sender;     // B: whoever is deploying and funding this contract right now
        // sender = address(this);  // C: the contract's own address — a contract is not a person
        // ------------------------------------------------------------------
        receiver = _receiver;
        hashlock = _hashlock;
        deadline = _deadline;
    }

    /// Bob (or anyone!) calls this with the secret to release the ETH to Bob.
    function withdraw(bytes32 secret) external {
        // ------------------------------------------------------------------
        // TODO 2 [WRITE] — the money must not have left already.
        // Write ONE require(...) line using the `settled` flag,
        // with the error message "already settled".
        // Syntax reminder:  require(<condition that must be true>, "message");
        // ------------------------------------------------------------------


        // ------------------------------------------------------------------
        // TODO 3 [WRITE] — claiming is only allowed BEFORE the deadline.
        // Write ONE require(...) comparing block.timestamp (the current time)
        // with `deadline`, error message "too late".
        // ------------------------------------------------------------------


        // ------------------------------------------------------------------
        // TODO 4 [CHOOSE] — check the secret. Remember: the contract only
        // knows the HASH of the secret, never the secret itself.
        // Uncomment exactly ONE:
        //
        // require(secret == hashlock, "wrong secret");                            // A: compare the secret to the hash directly
        // require(sha256(abi.encodePacked(secret)) == hashlock, "wrong secret");  // B: hash the submitted secret, compare hashes
        // require(sha256(abi.encodePacked(hashlock)) == secret, "wrong secret");  // C: hash the stored hash, compare to the secret
        // ------------------------------------------------------------------

        // ------------------------------------------------------------------
        // TODO 5 [WRITE] — mark the contract as settled, BEFORE the money
        // moves on the next line. (One short assignment, no require.)
        // ------------------------------------------------------------------


        // ------------------------------------------------------------------
        // TODO 6 [CHOOSE] — pay out. Note that ANYONE may have called this
        // function, not just Bob. Where should the money go?
        // Uncomment exactly ONE:
        //
        // payable(msg.sender).transfer(address(this).balance);  // A: whoever submitted the correct secret
        // payable(receiver).transfer(address(this).balance);    // B: the receiver chosen when the contract was created
        // payable(sender).transfer(address(this).balance);      // C: back to Alice — but she was buying, not refunding
        // ------------------------------------------------------------------
    }

    /// Alice calls this to take her money back if Bob never claimed in time.
    function refund() external {
        // Only the original sender may trigger the refund…
        require(msg.sender == sender, "not the sender");
        // …and never before Bob's claiming window has closed:
        require(block.timestamp >= deadline, "too early");
        // The settled flag guards this path too — a claimed contract cannot
        // also be refunded. You already wrote this check once in TODO 2;
        // write it again here yourself, no hint this time:
        // TODO 7 [WRITE]


        settled = true;
        payable(sender).transfer(address(this).balance);
    }
}
