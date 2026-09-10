// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./interfaces/IMultisigWallet.sol";

/*
 * ┌─────────────────────────────────────────────────────────────────────────┐
 * │ QUESTION 3 / CHECKPOINT 2 - MULTISIG WALLET                              │
 * │                                                                         │
 * │ Every blank is multiple choice: options A/B/C/D, each with a note on    │
 * │ what it does and how it differs. Uncomment EXACTLY ONE per question.    │
 * │                                                                         │
 * │ Run `forge test --mc Checkpoint2` after each change.                    │
 * │ For misconception feedback: `forge test --mc Checkpoint2Diagnostics -vv`│
 * └─────────────────────────────────────────────────────────────────────────┘
 *
 * ─── What is a multisig wallet, and how does this one work? ────────────────
 *
 * The wallets you built so far have ONE owner — one private key that can move
 * everything. Lose it (or get phished) and the money is gone. A MULTISIG
 * ("multiple signatures") wallet spreads that power across several people:
 * this one has 3 ADMINS, and any action needs approval from at least 2 of
 * them ("2-of-3"). No single compromised admin can drain it. This is how
 * companies, DAOs, and exchanges actually hold funds.
 *
 * The full lifecycle of one payment — say the admins want to send 1 ETH to
 * address R — walks through every function you are about to complete:
 *
 *   1. THE ACTION. "Send 1 ETH to R" is encoded as bytes: the calldata for
 *      this wallet's own transferEth(R, 1 ether) function. Those bytes are
 *      what everyone approves — approving "a payment", not a vague intent.
 *      Its keccak256 hash is the action's identity in all the mappings below.
 *
 *   2. APPROVING. Admin #1 calls approve(action); later admin #2 does the
 *      same. The contract records WHO approved WHAT (approvalsBy) and keeps
 *      a tally (approvalCount). Your Q2.4-Q2.6 decide: who may approve, how
 *      double-approval is blocked, and what gets recorded.
 *
 *   3. EXECUTING. Anyone calls execute(action). If the tally has reached
 *      THRESHOLD (2), the wallet marks the action as done — forever — and
 *      then performs it by CALLING ITSELF with the action bytes (that self-
 *      call lands in transferEth below). Your Q2.7-Q2.8 decide: how replay
 *      ("execute the same payment twice") is blocked, and whether an admin's
 *      execute() also counts as their approval.
 *
 *   4. transferEth REFUSES EVERYONE except the wallet itself (the self-call
 *      in step 3). That is the whole trick: the ONLY road to moving money
 *      goes through the approve-then-execute ceremony above.
 *
 * The constructor questions (Q2.1-Q2.3) set up the admin list this machinery
 * relies on. See the deployment guide at the bottom of this file for how to
 * actually play with the wallet in Remix.
 */
contract MultisigWallet is IMultisigWallet {
    uint256 constant ADMIN_COUNT = 3;
    uint256 constant THRESHOLD = 2;

    address[] public admins;
    mapping(bytes32 => mapping(address => bool)) public approvalsBy;
    mapping(bytes32 => uint256) public approvalCount;
    mapping(bytes32 => bool) public executed;

    constructor(address[] memory _admins) {
        /* ─── Q2.1: how do we validate admin count? ─────────────────────
           A) if (_admins.length != ADMIN_COUNT) revert BadConfig();
              Requires EXACTLY ADMIN_COUNT (3) admins; rejects both fewer and
              more. (Differs from B/C: exact match, not a lower bound.)
           B) require(_admins.length >= 2, "need at least 2");
              Accepts any count of 2 or more, including 4+.
           C) if (_admins.length == 0) revert BadConfig();
              Only rejects an empty list; accepts any non-zero count.
           D) (no length check)
              Accepts any length, including 0.
           Uncomment EXACTLY ONE: */
        // if (_admins.length != ADMIN_COUNT) revert BadConfig();
        // require(_admins.length >= 2, "need at least 2");
        // if (_admins.length == 0) revert BadConfig();
        //

        /* ─── Q2.2: how do we enforce admin uniqueness? ─────────────────
           A) require(_admins[0] != _admins[1] && _admins[1] != _admins[2]);
              Compares only the (0,1) and (1,2) pairs — MISSES the (0,2) pair, so
              [a, b, a] slips through. (Differs from B: incomplete pair coverage.)
           B) for (uint i; i < ADMIN_COUNT; i++) for (uint j = i + 1; j < ADMIN_COUNT; j++) if (_admins[i] == _admins[j]) revert BadConfig();
              Compares every distinct pair (i < j), catching all duplicates.
           C) for (uint i; i < ADMIN_COUNT; i++) for (uint j; j < ADMIN_COUNT; j++) if (_admins[i] == _admins[j]) revert BadConfig();
              Compares every pair INCLUDING i == j, so an element always equals
              itself — it reverts on every input. (Differs from B: j starts at 0.)
           D) (assume caller passes unique addresses)
              No uniqueness check at all.
           Uncomment EXACTLY ONE: */
        // require(_admins[0] != _admins[1] && _admins[1] != _admins[2]);
        // for (uint i; i < ADMIN_COUNT; i++) for (uint j = i + 1; j < ADMIN_COUNT; j++) if (_admins[i] == _admins[j]) revert BadConfig();
        // for (uint i; i < ADMIN_COUNT; i++) for (uint j; j < ADMIN_COUNT; j++) if (_admins[i] == _admins[j]) revert BadConfig();
        //

        /* ─── Q2.3: how do we store the admins? ─────────────────────────
           A) admins = _admins;
              Copies the whole memory array into storage in one assignment,
              resizing the storage array to match. (Differs from C: whole-array
              copy handles the length for you.)
           B) for (uint i; i < ADMIN_COUNT; i++) admins.push(_admins[i]);
              Appends each element one at a time; also fills the array (slightly
              more gas than A).
           C) for (uint i; i < ADMIN_COUNT; i++) admins[i] = _admins[i];
              Indexes into a still-empty (length 0) storage array, which is out
              of bounds and reverts.
           D) (skip — let the array stay empty)
              Leaves `admins` empty, so reads like admins(0) revert.
           Uncomment EXACTLY ONE (A or B is a single line; C is one line in a loop): */
        // admins = _admins;
        // for (uint i; i < ADMIN_COUNT; i++) admins.push(_admins[i]);
        // for (uint i; i < ADMIN_COUNT; i++) admins[i] = _admins[i];
        //
    }

    receive() external payable {}

    function _isAdmin(address account) internal view returns (bool) {
        for (uint256 i = 0; i < admins.length; i++) {
            if (admins[i] == account) return true;
        }
        return false;
    }

    function approve(bytes calldata action) external {
        /* ─── Q2.4: who can call approve? ───────────────────────────────
           A) if (!_isAdmin(msg.sender)) revert NotAuthorized();
              Allows only admins, checked by the immediate caller.
           B) if (msg.sender == address(this)) revert NotAuthorized();
              Only blocks the contract calling itself; lets ANY external account
              approve. (Differs from A: not an admin check.)
           C) require(_isAdmin(tx.origin), "not admin");
              Checks the originating EOA instead of the direct caller; phishable
              via an intermediary contract.
           D) (no check — anyone may approve)
              No authorization on approve.
           Uncomment EXACTLY ONE: */
        // if (!_isAdmin(msg.sender)) revert NotAuthorized();
        // if (msg.sender == address(this)) revert NotAuthorized();
        // require(_isAdmin(tx.origin), "not admin");
        //

        /* ─── Q2.5: how do we block double-approval by the same admin? ──
           A) if (approvalsBy[keccak256(action)][msg.sender]) revert AlreadyApproved();
              Reverts if THIS admin already approved THIS action — the exact
              re-approval case. (Differs from B/C: per-admin, per-action.)
           B) if (approvalCount[keccak256(action)] >= THRESHOLD) revert AlreadyApproved();
              Reverts once the threshold is reached, regardless of who; does not
              stop the same admin approving twice before the threshold.
           C) if (executed[keccak256(action)]) revert AlreadyApproved();
              Checks whether the action was already executed — a different
              concern from re-approval.
           D) (no guard)
              Nothing stops an admin from approving the same action repeatedly.
           Uncomment EXACTLY ONE: */
        // if (approvalsBy[keccak256(action)][msg.sender]) revert AlreadyApproved();
        // if (approvalCount[keccak256(action)] >= THRESHOLD) revert AlreadyApproved();
        // if (executed[keccak256(action)]) revert AlreadyApproved();
        //

        /* ─── Q2.6: how do we record the approval? ──────────────────────
           A) approvalsBy[keccak256(action)][msg.sender] = true; approvalCount[keccak256(action)] += 1;
              Records WHO approved (the flag) AND bumps the tally (the count) —
              both pieces the threshold logic needs.
           B) approvalsBy[keccak256(action)][msg.sender] = true;
              Sets the flag only; the count never rises, so the threshold is
              never reached.
           C) approvalCount[keccak256(action)] += 1;
              Bumps the count only; without the flag, the double-approve guard
              can't tell admins apart.
           D) approvalsBy[keccak256(action)][msg.sender] = true; approvalCount[keccak256(action)] = 1;
              Sets the flag but PINS the count at 1 each time, so it never
              reaches 2. (Differs from A: assigns 1 instead of incrementing.)
           Uncomment EXACTLY ONE (A and D are TWO statements — uncomment BOTH lines for that choice): */
        // approvalsBy[keccak256(action)][msg.sender] = true; approvalCount[keccak256(action)] += 1;
        // approvalsBy[keccak256(action)][msg.sender] = true;
        // approvalCount[keccak256(action)] += 1;
        // approvalsBy[keccak256(action)][msg.sender] = true; approvalCount[keccak256(action)] = 1;

        emit Approved(msg.sender, action);
    }

    function execute(bytes calldata action) external {
        bytes32 h = keccak256(action);

        /* ─── Q2.7: how do we prevent replay? ───────────────────────────
           A) if (executed[h]) revert NotAuthorized();
              Reverts on re-execution with the custom error NotAuthorized().
              (Differs from B: custom error vs. string.)
           B) require(!executed[h], "already executed");
              Same logic but reverts with a string Error(string) instead of the
              custom error the test expects.
           C) executed[h] = true;  // mark BEFORE checking (no guard)
              Sets the flag but never checks it, so it does not actually block a
              second execution.
           D) (skip — assume the always-present `executed[h] = true` below is enough)
              Relies on the line further down that is only set, never read here —
              so nothing blocks replay.
           Uncomment EXACTLY ONE: */
        // if (executed[h]) revert NotAuthorized();
        // require(!executed[h], "already executed");
        // executed[h] = true;
        //

        /* ─── Q2.8: auto-approve when an admin calls execute ────────────
           A) if (_isAdmin(msg.sender) && !approvalsBy[h][msg.sender]) { approvalsBy[h][msg.sender] = true; approvalCount[h] += 1; emit Approved(msg.sender, action); }
              Counts the admin's execute() as their approval, but ONLY if they
              hadn't approved yet — supports the approve+execute two-call flow
              without double-counting. (Differs from B: the !already-approved guard.)
           B) if (_isAdmin(msg.sender)) { approvalsBy[h][msg.sender] = true; approvalCount[h] += 1; }
              Counts an admin's execute() even if they already approved, so an
              admin can inflate their own approval.
           C) (skip — require pre-approval)
              An admin's execute() does NOT count as an approval; you need
              separate prior approvals.
           D) approvalCount[h] += 1;  // unconditional, even non-admin
              Increments for ANY caller, including non-admins.
           Uncomment EXACTLY ONE (A and B span multiple lines — uncomment the WHOLE block): */
        // if (_isAdmin(msg.sender) && !approvalsBy[h][msg.sender]) {
        //     approvalsBy[h][msg.sender] = true;
        //     approvalCount[h] += 1;
        //     emit Approved(msg.sender, action);
        // }
        // if (_isAdmin(msg.sender)) {
        //     approvalsBy[h][msg.sender] = true;
        //     approvalCount[h] += 1;
        // }
        // approvalCount[h] += 1;

        // Threshold check + effects-then-interactions (these stay always-present, not part of any MCQ).
        if (approvalCount[h] < THRESHOLD) revert NotAuthorized();
        executed[h] = true;
        (bool success,) = address(this).call(action);
        require(success);
        emit Executed(msg.sender, action);
    }

    function transferEth(address payable recipient, uint256 amount) external {
        // Self-call gate — always-present (intentionally NOT an MCQ because the
        // test relies on the precise revert selector and there is no useful distractor space here).
        if (msg.sender != address(this)) revert NotAuthorized();
        (bool ok,) = recipient.call{value: amount}("");
        if (!ok) revert FailedTransfer();
    }
}

/* ═══════════════════════════════════════════════════════════════════════════
   BEFORE YOU MOVE ON — self-check
   ───────────────────────────────────────────────────────────────────────────
   Question index for this file:
     Q2.1  constructor  — how strictly is the admin count validated?
     Q2.2  constructor  — how are duplicate admins caught?
     Q2.3  constructor  — how is the admin list stored?
     Q2.4  approve      — who may approve?
     Q2.5  approve      — how is double-approval by one admin blocked?
     Q2.6  approve      — what exactly gets recorded?
     Q2.7  execute      — how is executing the same action twice blocked?
     Q2.8  execute      — does an admin's execute() count as their approval?

   For EACH question, confirm you uncommented EXACTLY ONE option.
   A skipped question still compiles: compiling is not the answer key.
   Graded tests (terminal): cd lab/opt1 && forge test --mc Checkpoint2

   ───────────────────────────────────────────────────────────────────────────
   TRY IT IN REMIX — deploying a wallet that needs THREE owners
   ───────────────────────────────────────────────────────────────────────────
   Unlike BasicWallet, this constructor takes an argument: address[] _admins.
   In the Deploy & Run tab, the field next to the Deploy button must hold a
   JSON array of 3 addresses — with an empty field you get
   "Error encoding arguments: expected array value".

   Where do 3 addresses come from? The ACCOUNT dropdown at the top of the
   Deploy tab lists the Remix VM's pre-funded test accounts. Pick any three
   (copy icon next to the dropdown), e.g. the first three:

   ["0x5B38Da6a701c568545dCfcB03FcB875f56beddC4","0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2","0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db"]

   To play a full 2-of-3 payment: deploy with those three, send the wallet
   some ETH (VALUE + the low-level "Transact" with empty calldata hits your
   receive()), then switch the ACCOUNT dropdown to admin #1 and call
   approve(action), switch to admin #2 and call execute(action) — switching
   the dropdown is how you "become" a different caller in Remix. The action
   bytes are the ABI-encoded call to transferEth; in the graded forge tests
   this encoding is produced for you.
   ═══════════════════════════════════════════════════════════════════════════ */
