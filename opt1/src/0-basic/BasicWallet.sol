// SPDX-License-Identifier: MIT
// ^ A machine-readable license tag. Solidity expects every source file to
//   declare one. "MIT" is a permissive open-source license. This is metadata
//   only — it does not affect how the code runs.

pragma solidity ^0.8.13;
// ^ "pragma" tells the COMPILER which Solidity language version this file
//   targets. "^0.8.13" means "any 0.8.x version that is 0.8.13 or newer, but
//   not 0.9". Solidity 0.8+ has built-in overflow checks on arithmetic.

import "./interfaces/IBasicWallet.sol";
// ^ Pulls in another Solidity file so we can use the names it defines. The
//   imported file declares an INTERFACE (a list of function signatures this
//   contract promises to provide) and two custom ERRORS (NotAuthorized,
//   FailedTransfer). Think of it like `import` in Python or `#include` in C.

/*
 * ┌─────────────────────────────────────────────────────────────────────┐
 * │ QUESTION 3 / CHECKPOINT 0 - BASIC SMART-CONTRACT WALLET             │
 * │ MCQ format: each blank below is a multiple-choice question.         │
 * │ Every option (A/B/C/D) has a plain-English note saying what it      │
 * │ does and how it differs from the others. Read them, then pick       │
 * │ EXACTLY ONE option per question and uncomment its line(s).          │
 * │ All four options compile. Some pass the tests; some fail.           │
 * │ Run `forge test --mc Checkpoint0` after each pick.                  │
 * │ For misconception feedback: `forge test --mc Checkpoint0Diagnostics -vv` │
 * └─────────────────────────────────────────────────────────────────────┘
 */
// ─── What is a "contract"? ────────────────────────────────────────────────
// A `contract` in Solidity is the closest thing to a CLASS in Java/Python/C++.
// Once deployed, it lives at its own Ethereum address and holds two things:
//   1) STATE (variables stored on-chain, persistent across calls), and
//   2) CODE (functions that anyone — or only authorized callers — can invoke).
// `is IBasicWallet` means this contract IMPLEMENTS the IBasicWallet interface
// (similar to Java's `implements` or Python's abstract base class). The
// compiler will check that every function the interface promises is provided.
contract BasicWallet is IBasicWallet {

    // ─── State variable ────────────────────────────────────────────────────
    // `address` is a 20-byte Ethereum account identifier (looks like
    // 0xAb12...Ef34). It can refer to an externally-owned account (a human's
    // wallet) or another contract.
    // `public` does two things: (1) the variable is readable from outside the
    // contract, and (2) Solidity AUTO-GENERATES a getter function named
    // `owner()` that returns it — which is exactly what IBasicWallet requires.
    // Because this is a STATE variable (declared at contract scope, not inside
    // a function), its value is persisted on the blockchain across calls.
    address public owner;

    // ─── What is a "constructor"? ──────────────────────────────────────────
    // A constructor is a SPECIAL function that runs EXACTLY ONCE — at the
    // moment the contract is deployed to the blockchain. After deployment it
    // cannot be called again. Its job is usually to initialize state. Here,
    // we use it to record WHO OWNS this wallet, so later only that person is
    // allowed to move ETH out of it.
    // (Same idea as `__init__` in Python or a class constructor in Java/C++,
    //  but it runs on-chain at deployment time, not when you "new" an object.)
    constructor() {
        /* ─── Q0.1: how do we set the owner? ─────────────────────────────
           First, the two deployment scenarios you must keep in mind — the
           options only differ in the SECOND one:

             Scenario 1 (what our tests do): a person deploys the wallet
                 Alice (EOA) ──deploys──> BasicWallet
                 inside the constructor:  msg.sender = Alice, tx.origin = Alice
                 (identical — you cannot tell A and B apart here)

             Scenario 2 (common in real life): a CONTRACT deploys the wallet,
             e.g. a "factory" that mass-produces wallets for users
                 Alice (EOA) ──calls──> Factory ──deploys──> BasicWallet
                 inside the constructor:  msg.sender = Factory, tx.origin = Alice

           msg.sender = whoever is ONE step up the call chain (the direct
                        caller). In Scenario 2 that is the Factory contract.
           tx.origin  = the EOA that SIGNED the very first transaction, no
                        matter how many contracts sit in between. In Scenario 2
                        that is Alice — the Factory is skipped entirely.

           A) owner = tx.origin;
              Scenario 1: owner = Alice (looks fine, tests pass).
              Scenario 2: owner = Alice too — the Factory that actually
              deployed the wallet is NOT recorded. Whether that's what you
              want is a design decision the Factory should make explicitly
              (e.g. by passing an owner argument), not something to inherit
              silently from tx.origin.
           B) owner = msg.sender;
              Scenario 1: owner = Alice. Scenario 2: owner = Factory, which
              can then transfer or manage ownership deliberately. This is the
              standard Solidity idiom: trust your DIRECT caller, let it decide.
           C) owner = address(this);
              owner = the wallet's OWN address in both scenarios. Nobody can
              ever call the wallet FROM the wallet's address, so every
              owner-only check will reject everyone — the wallet is bricked.
           D) (leave as the default address(0))
              owner stays address(0), the "null" address nobody controls.
              Same effect as C: nothing can ever authorize — bricked.
           Uncomment EXACTLY ONE: */
        /* ┌─────────────────────────────────────────────────────────────────┐
         * │  >>> YOUR TURN: UNCOMMENT EXACTLY ONE OPTION LINE BELOW <<<      │
         * │  Delete the leading "// " on the ONE line you pick so it         │
         * │  becomes real code. Leave the other lines commented out.         │
         * │  For option D, leave ALL three lines commented (do nothing).     │
         * └─────────────────────────────────────────────────────────────────┘ */
        // Option A — owner becomes the original signing EOA (tx.origin):
        // owner = tx.origin;
        //
        // Option B — owner becomes the direct caller of the constructor
        // (msg.sender), i.e. whoever sent the deploy transaction:
        // owner = msg.sender;
        //
        // Option C — owner becomes the wallet contract's OWN address
        // (no external account can ever match this):
        // owner = address(this);
        //
        // Option D — do nothing; owner stays at the default address(0).
    }

    /* ─── Q0.2: how do we accept plain ETH transfers? ───────────────────
       A) receive() external payable {}
          The dedicated function the EVM runs for a plain ETH transfer (empty
          calldata + value > 0). (Differs from B: purpose-built for plain ETH.)
       B) fallback() external payable {}
          A catch-all that ALSO accepts plain ETH, but is really meant for calls
          to unknown function selectors. (Differs from A: general-purpose, not
          ETH-specific.)
       C) function deposit() external payable {}
          Only runs when the caller explicitly invokes deposit(); a plain ETH
          send (empty calldata) never reaches it. (Differs from A/B: needs its
          selector in the calldata.)
       D) (no special function — let the default behavior apply)
          With neither receive nor a payable fallback, the contract rejects
          plain ETH sends.
       Uncomment EXACTLY ONE of the function declarations below: */
    // Quick vocabulary for the lines below — TWO SEPARATE ideas, don't mix:
    //
    // (1) WHAT `receive` / `fallback` ARE: special functions. You declare
    //     them WITHOUT the `function` keyword, and you never call them by
    //     name — the EVM invokes one automatically when a call doesn't
    //     target any regular function (for `receive`: a plain ETH transfer
    //     with empty calldata). By contrast, `deposit` in option C is an
    //     ordinary function that only runs when called by name.
    //
    // (2) THE MODIFIERS after the parentheses — these apply to any function,
    //     special or ordinary:
    //     • `external` — callable from outside the contract (by users or
    //                    other contracts), not from inside it directly.
    //     • `payable`  — allowed to receive ETH along with the call. Without
    //                    it, any attached ETH makes the transaction revert.

    /* ┌─────────────────────────────────────────────────────────────────────┐
     * │  >>> YOUR TURN: UNCOMMENT EXACTLY ONE OPTION LINE BELOW <<<          │
     * │  Delete the leading "// " on the ONE function you pick so it         │
     * │  becomes a real function declaration. Leave the others commented.    │
     * │  For option D, leave ALL three lines commented (do nothing).         │
     * └─────────────────────────────────────────────────────────────────────┘ */
    // Option A — dedicated receive() for plain ETH transfers:
    // receive() external payable {}
    //
    // Option B — catch-all fallback() that also accepts ETH:
    // fallback() external payable {}
    //
    // Option C — explicit deposit() function (must be called by name):
    // function deposit() external payable {}
    //
    // Option D — do nothing; contract rejects plain ETH sends.

    // ─── A regular function ────────────────────────────────────────────────
    // Anatomy of the signature:
    //   function transferEth( ... ) external
    //   ^ keyword  ^ name      ^ params  ^ visibility (callable from outside)
    // Parameters:
    //   • `address payable recipient` — an Ethereum address that is marked as
    //     able to RECEIVE ETH. Only `payable` addresses can be sent ETH.
    //   • `uint256 amount` — an unsigned 256-bit integer. ETH amounts are
    //     stored in WEI (1 ETH = 10^18 wei), and uint256 is plenty large.

    function transferEth(address payable recipient, uint256 amount) external {
        /* ─── Q0.3: how do we authorize only the owner? ─────────────────
           A) if (msg.sender != owner) revert NotAuthorized();
              Rejects any DIRECT caller other than the owner, and rejects
              LOUDLY: the transaction reverts, all its effects are undone, and
              the caller receives the NotAuthorized error.
           B) if (tx.origin != owner) revert NotAuthorized();
              Checks who SIGNED the transaction instead of who is calling right
              now. Works in everyday use — but recall the call-chain picture
              from Q0.1 and consider this attack:

                owner ──calls──> EvilContract ──calls──> wallet.transferEth(attacker, ALL)

              Inside transferEth: msg.sender = EvilContract (option A blocks
              this), but tx.origin = owner — so option B lets the transfer
              through. The owner only had to be tricked into calling ANY
              function of EvilContract (a fake airdrop claim, a malicious NFT
              mint) and their wallet is drained. Contrast with Q0.1: STORING
              tx.origin as owner at deploy time was merely imprecise;
              TRUSTING tx.origin for authorization is exploitable. Note the
              trap: picking tx.origin in BOTH Q0.1 and Q0.3 looks consistent
              and passes normal use — and is exactly the phishable wallet.
           C) if (msg.sender != owner) return;
              Same condition as A, but FAILS SILENTLY: instead of reverting,
              the function just stops. The non-owner's transaction SUCCEEDS
              while doing nothing. Funds are safe, but callers, front-ends,
              and tests cannot tell "rejected" from "worked" — a composability
              bug. (Our test expects an unauthorized call to REVERT with
              NotAuthorized, so this fails the test.)
           D) (no check — anyone can call)
              No authorization at all; any caller may move funds.
           Uncomment EXACTLY ONE: */
        // Vocabulary for the options:
        //   • `revert SomeError();` — aborts the transaction, undoes ALL state
        //          changes made so far, and reports the error to the caller.
        //          "Pretend this call never happened, and say why."
        //   • `return;` — ends the function normally. The transaction still
        //          counts as SUCCESSFUL; it just did less than expected.
        // Failing loudly (revert) is the norm on Ethereum: other contracts and
        // UIs compose with yours by assuming "no revert" means "it worked".

        /* ┌─────────────────────────────────────────────────────────────────┐
         * │  >>> YOUR TURN: UNCOMMENT EXACTLY ONE OPTION LINE BELOW <<<      │
         * │  Delete the leading "// " on the ONE line you pick so the check  │
         * │  becomes real code. Leave the other lines commented out.         │
         * │  For option D, leave ALL three lines commented (no check).       │
         * └─────────────────────────────────────────────────────────────────┘ */
        // Option A — check the direct caller, revert with custom error:
        // if (msg.sender != owner) revert NotAuthorized();
        //
        // Option B — check the original signing EOA (phishing-vulnerable):
        // if (tx.origin != owner) revert NotAuthorized();
        //
        // Option C — same condition as A but exits silently instead of reverting:
        // if (msg.sender != owner) return;
        //
        // Option D — do nothing; anyone can call this function.

        /* ─── Q0.4: how do we send the ETH? ─────────────────────────────
           A) payable(recipient).transfer(amount);
              Forwards only a fixed 2300 gas and reverts on failure. (Differs
              from B: capped gas, so it fails if the recipient's receive() does
              real work.)
           B) (bool ok,) = recipient.call{value: amount}(""); if (!ok) revert FailedTransfer();
              Forwards all remaining gas, returns a success flag, and reverts
              with FailedTransfer() if the send fails. (Differs from A/C: no gas
              cap.)
           C) payable(recipient).send(amount);
              Like A (2300 gas) but returns false instead of reverting, so a
              failed send passes silently unless you check the bool. (Differs
              from A: silent failure.)
           D) selfdestruct(payable(recipient));
              Destroys the wallet contract and forwards its WHOLE balance once;
              the contract no longer exists afterward. (Differs from A/B/C: not
              a normal transfer.)
           Uncomment EXACTLY ONE (B is two statements — uncomment BOTH lines): */
        // Background on the three native ways to send ETH in Solidity:
        //   • `.transfer(amount)` — sends ETH, forwards only 2300 gas, REVERTS
        //                           on failure. Safe but inflexible.
        //   • `.send(amount)`     — same 2300 gas, but returns a bool instead
        //                           of reverting on failure (silent failure
        //                           unless you check the bool).
        //   • `.call{value: amount}("")` — low-level call. Forwards ALL gas by
        //                           default. Returns (bool success, bytes data).
        //                           The modern recommended pattern: check the
        //                           bool and revert manually on failure.
        // In option B below, `(bool ok,)` is destructuring — we grab the
        // success flag and ignore the returned data bytes.

        /* ┌─────────────────────────────────────────────────────────────────┐
         * │  >>> YOUR TURN: UNCOMMENT EXACTLY ONE OPTION BELOW <<<           │
         * │  Delete the leading "// " on the ONE option you pick. Option B   │
         * │  is TWO statements on one line — uncomment the WHOLE line.       │
         * └─────────────────────────────────────────────────────────────────┘ */
        // Option A — .transfer(): 2300 gas, reverts on failure:
        // payable(recipient).transfer(amount);
        //
        // Option B — low-level .call(): forwards all gas, manual revert:
        // (bool ok,) = recipient.call{value: amount}(""); if (!ok) revert FailedTransfer();
        //
        // Option C — .send(): 2300 gas, returns bool (silent failure here):
        // payable(recipient).send(amount);
        //
        // Option D — selfdestruct: destroys contract, forwards whole balance:
        // selfdestruct(payable(recipient));
    }
}

/* ═══════════════════════════════════════════════════════════════════════════
   BEFORE YOU MOVE ON — self-check
   ───────────────────────────────────────────────────────────────────────────
   Question index for this file:
     Q0.1  constructor    — who gets recorded as `owner`?
     Q0.2  contract body  — how does the wallet accept plain ETH?
     Q0.3  transferEth    — who is allowed to move the funds?
     Q0.4  transferEth    — how is the ETH actually sent?

   For EACH question, confirm you uncommented EXACTLY ONE option (for a
   "do nothing" option, all lines stay commented — that IS your answer).
   A skipped question still compiles: compiling is not the answer key.

   Checking your work:
   • Quick syntax check in Remix: open this file, Solidity Compiler tab,
     any 0.8.13+ version, Compile. (See REMIX_GUIDE.md at the repo root.)
     Remix can only tell you the syntax is valid — every option compiles.
   • Graded tests (terminal):   cd lab/opt1 && forge test --mc Checkpoint0
     Misconception feedback:    forge test --mc Checkpoint0Diagnostics -vv
   ═══════════════════════════════════════════════════════════════════════════ */
