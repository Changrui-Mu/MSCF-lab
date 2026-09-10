// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./interfaces/IERC20Wallet.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/*
 * ┌─────────────────────────────────────────────────────────────────────────┐
 * │ QUESTION 3 / CHECKPOINT 1 - ERC-20 WALLET                               │
 * │                                                                         │
 * │ This file has two kinds of blanks:                                      │
 * │  • ">>> YOUR CODE (k/5)" — WRITE the line(s) yourself. Each box says    │
 * │    exactly what your code must do.                                      │
 * │  • Q1.1 and Q1.2 — multiple choice: uncomment exactly ONE option.       │
 * │                                                                         │
 * │ Run `forge test --mc Checkpoint1` after each change.                    │
 * │ For misconception feedback: `forge test --mc Checkpoint1Diagnostics -vv`│
 * └─────────────────────────────────────────────────────────────────────────┘
 *
 * ─── ETH vs ERC-20: two completely different kinds of "balance" ───────────
 *
 * Everything in this checkpoint follows from one picture. ETH is the NATIVE
 * asset of Ethereum: every address has a built-in ETH balance maintained by
 * the protocol itself, and moving ETH is a primitive operation (a value
 * transfer attached to a call). That's the world of checkpoint 0.
 *
 * An ERC-20 token is NOT native. It is just a CONTRACT that keeps a ledger
 * in its own storage:
 *
 *      contract SomeToken {
 *          mapping(address => uint256) balanceOf;                    // the ledger
 *          mapping(address => mapping(address => uint256)) allowance;
 *          function transfer(address to, uint256 amount) ...         // edits the ledger
 *          function approve(address spender, uint256 amount) ...
 *      }
 *
 * "Your wallet holds 100 USDC" really means: the USDC contract's ledger has
 * an entry balanceOf[yourWallet] == 100. The tokens never "arrive at" your
 * wallet — nothing about your wallet's own storage or ETH balance changes.
 *
 * Three consequences that shape the code below:
 *   1. RECEIVING tokens requires NO code in the wallet. When someone calls
 *      token.transfer(wallet, 100), the TOKEN contract updates its own
 *      mapping; the wallet is never even called. (Compare: receiving ETH
 *      required a receive() function!)
 *   2. SENDING tokens means the wallet must CALL the token contract and ask
 *      it to edit the ledger: token.transfer(recipient, amount), executed
 *      with the wallet as msg.sender.
 *   3. APPROVING is ledger-level delegation: token.approve(spender, n) lets
 *      `spender` later move up to n of the wallet's tokens via transferFrom.
 *      This is how DEXes and other protocols get permission to pull tokens.
 *
 * One more real-world wrinkle: the ERC-20 "standard" is loosely followed.
 * Some major tokens (USDT!) deviate just enough to break naive integrations.
 * The two MCQs below are exactly about surviving those deviations.
 */
contract ERC20Wallet is IERC20Wallet {
    using SafeERC20 for IERC20;

    address public owner;

    constructor() {
        /* ┌─────────────────────────────────────────────────────────────────┐
         * │ >>> YOUR CODE (1/5): set the owner                               │
         * │ In checkpoint 0 this was Q0.1 — now write it yourself.           │
         * │ Record the account that deployed the wallet as `owner` (1 line). │
         * └─────────────────────────────────────────────────────────────────┘ */
    }

    /* ┌─────────────────────────────────────────────────────────────────────┐
     * │ >>> YOUR CODE (2/5): accept plain ETH                                │
     * │ Q0.2 asked which special function makes a contract accept plain      │
     * │ ETH transfers. Declare it here (1 line). Note there is no such       │
     * │ step for ERC-20 tokens — consequence #1 above explains why.          │
     * └─────────────────────────────────────────────────────────────────────┘ */

    function transferEth(address payable recipient, uint256 amount) external {
        /* ┌─────────────────────────────────────────────────────────────────┐
         * │ >>> YOUR CODE (3/5): authorize, then send ETH                    │
         * │ This was Q0.3 + Q0.4 — now write both lines yourself:            │
         * │   1. Only the owner may proceed; anyone else must be rejected    │
         * │      LOUDLY with the custom error NotAuthorized().               │
         * │   2. Send `amount` wei to `recipient` using the pattern that     │
         * │      (a) forwards enough gas for contract recipients and         │
         * │      (b) reverts with FailedTransfer() if the send fails.        │
         * └─────────────────────────────────────────────────────────────────┘ */
    }

    function transferERC20(address token, address recipient, uint256 amount) external {
        /* ┌─────────────────────────────────────────────────────────────────┐
         * │ >>> YOUR CODE (4/5): authorization                               │
         * │ Same check as in transferEth (1 line). Note what we are          │
         * │ protecting: not ETH this time, but the wallet's entry in the     │
         * │ token contract's ledger.                                         │
         * └─────────────────────────────────────────────────────────────────┘ */

        /* ─── Q1.1: how do we send the ERC-20? ──────────────────────────
           This is the NEW material. All four options compile; use the ledger
           picture from the header to see which contract each one talks to
           and whose balance it moves.

           A) IERC20(token).transfer(recipient, amount);
              The textbook call: asks the token contract to move `amount` from
              the wallet's ledger entry to the recipient's. Works on
              standards-compliant tokens. BUT: the IERC20 interface promises
              `transfer` returns a bool, so Solidity generates code that
              decodes 32 bytes of return data. USDT's transfer returns
              NOTHING → the decode step reverts in YOUR wallet, even though
              the token's ledger update itself succeeded.
           B) IERC20(token).safeTransfer(recipient, amount);
              OpenZeppelin's wrapper around the same call. It uses a low-level
              call and only decodes a bool if return data is actually present,
              so it works on BOTH standard tokens and USDT-style tokens.
           C) IERC20(token).transferFrom(msg.sender, recipient, amount);
              The DELEGATION primitive, pointed the wrong way: it tries to move
              tokens out of msg.sender's (the owner's) ledger entry, spending
              an allowance the wallet was never granted → reverts. The wallet
              wants to move ITS OWN entry, which is plain `transfer`.
           D) (bool ok,) = recipient.call(abi.encodeWithSignature("transfer(address,uint256)", recipient, amount)); require(ok);
              Hand-rolled low-level call — but aimed at `recipient` instead of
              `token`. Remember the ledger lives in the TOKEN contract; calling
              transfer(...) on an EOA recipient hits an address with no code,
              which "succeeds" doing nothing. No tokens move, no error raised.
           Uncomment EXACTLY ONE: */
        /* ┌─────────────────────────────────────────────────────────────────┐
         * │  >>> YOUR TURN: UNCOMMENT EXACTLY ONE OPTION LINE BELOW <<<      │
         * └─────────────────────────────────────────────────────────────────┘ */
        // Option A — typed interface call, expects a bool back:
        // IERC20(token).transfer(recipient, amount);
        //
        // Option B — OpenZeppelin SafeERC20, tolerant of missing return data:
        // IERC20(token).safeTransfer(recipient, amount);
        //
        // Option C — allowance-based pull from msg.sender (wrong primitive):
        // IERC20(token).transferFrom(msg.sender, recipient, amount);
        //
        // Option D — low-level call aimed at the recipient (wrong contract):
        // { (bool ok,) = recipient.call(abi.encodeWithSignature("transfer(address,uint256)", recipient, amount)); require(ok); }
    }

    function approveERC20(address token, address spender, uint256 amount) external {
        /* ┌─────────────────────────────────────────────────────────────────┐
         * │ >>> YOUR CODE (5/5): authorization                               │
         * │ Same check once more (1 line). An unauthorized approve is just   │
         * │ as dangerous as an unauthorized transfer — the spender can pull  │
         * │ the tokens out later with transferFrom.                          │
         * └─────────────────────────────────────────────────────────────────┘ */

        /* ─── Q1.2: how do we set the allowance? ────────────────────────
           Trace ONE worked example through every option. Suppose the wallet's
           current allowance to `spender` is 50, and the owner now calls
           approveERC20(token, spender, 70) — intending the allowance to BE 70.

           A) IERC20(token).approve(spender, amount);
              The textbook call: sets the ledger's allowance entry directly,
              50 → 70. Works on standard tokens. BUT USDT forbids changing a
              non-zero allowance to another non-zero value (you must go
              through 0 first — an anti-front-running rule), so on USDT this
              exact 50 → 70 call REVERTS.
           B) IERC20(token).forceApprove(spender, amount);
              OpenZeppelin helper that performs the two-step dance for you:
              50 → 0 → 70. Ends with allowance == 70 on every token,
              including USDT.
           C) IERC20(token).safeIncreaseAllowance(spender, amount);
              ADDS instead of SETS: 50 + 70 → allowance becomes 120. Nothing
              reverts, which makes this the sneakiest wrong answer — the
              spender ends up authorized for 50 more than intended.
           D) IERC20(token).transfer(spender, amount);
              Confuses the two ledgers: allowance stays 50, and 70 tokens are
              irreversibly SENT to the spender instead.
           Uncomment EXACTLY ONE: */
        /* ┌─────────────────────────────────────────────────────────────────┐
         * │  >>> YOUR TURN: UNCOMMENT EXACTLY ONE OPTION LINE BELOW <<<      │
         * └─────────────────────────────────────────────────────────────────┘ */
        // Option A — plain approve, sets the value directly:
        // IERC20(token).approve(spender, amount);
        //
        // Option B — forceApprove: reset to 0, then set the new value:
        // IERC20(token).forceApprove(spender, amount);
        //
        // Option C — safeIncreaseAllowance: adds to the current allowance:
        // IERC20(token).safeIncreaseAllowance(spender, amount);
        //
        // Option D — transfer: moves tokens, does not touch the allowance:
        // IERC20(token).transfer(spender, amount);
    }
}
