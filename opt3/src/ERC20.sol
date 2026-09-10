// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
 * ┌───────────────────────────────────────────────────────────────────────────┐
 * │  QUESTION 1 / CHECKPOINT 0 - ERC-20 PAYMENT TOKEN  (Q1-Q6)                 │
 * │                                                                            │
 * │  This is the currency buyers bid with. The marketplace escrows it during   │
 * │  an auction, so it must move tokens correctly. Six decisions are left      │
 * │  blank. UNCOMMENT EXACTLY ONE option per question (A/B/C, sometimes D).    │
 * │  Some options compile and pass; some compile but FAIL the tests; a few     │
 * │  don't even compile — reason about each option before you build.           │
 * │  The correct answer's position (A/B/C/D) carries NO signal.                │
 * │                                                                            │
 * │    forge test --mc Checkpoint0      # this file (Q1-Q6)                    │
 * └───────────────────────────────────────────────────────────────────────────┘
 *
 * ─── What here is "the standard", and what is implementation? ────────────────
 * EIP-20 only fixes the contract's PUBLIC INTERFACE — the function signatures
 * and events every ERC-20 must expose so that wallets, exchanges, and our
 * marketplace can talk to any token the same way:
 *   • functions: transfer, transferFrom, approve, balanceOf, allowance,
 *                totalSupply  (+ optional metadata: name, symbol, decimals)
 *   • events:    Transfer, Approval
 * Everything INSIDE those functions is up to the implementer — which is why
 * this file exists (and why weird tokens like USDT can deviate). Note two
 * Solidity conveniences we lean on:
 *   • `public` state variables (name, symbol, decimals, totalSupply, and the
 *     two mappings) AUTO-GENERATE their standard getter functions — we never
 *     write balanceOf() by hand; the mapping declaration below IS the getter.
 *   • `transfer` and `approve` at the bottom of this file are given complete:
 *     they are thin wrappers around the standard's required behavior.
 */



// Add questions 

contract ERC20 {
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // The two events required by EIP-20. Every balance change must emit
    // Transfer; every allowance change must emit Approval (see Q4 for what
    // "emitting" actually does).
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    constructor(uint256 initialSupply, string memory tokenName, string memory tokenSymbol) {
        // `decimals` is 18, so one whole token is 10**18 base units. The supply
        // is stored in base units:
        totalSupply = initialSupply * 10 ** uint256(decimals);

        /* ─── Q1: give the entire initial supply to the deployer. ─────────────
           Background: `msg.sender` in a constructor is the account that deployed
           the contract. `totalSupply` (set just above) is already scaled by the
           18 decimals; `initialSupply` is the raw, UNscaled argument.
           A) balanceOf[msg.sender] = initialSupply; — credits the deployer the
              unscaled argument (1_000_000 base units, i.e. 10**-12 of one whole
              token when decimals is 18).
           B) balanceOf[msg.sender] = totalSupply; — credits the deployer the
              decimals-scaled supply computed above.
           C) leave it blank — nobody is ever credited any tokens.
           UNCOMMENT EXACTLY ONE: */
        // balanceOf[msg.sender] = initialSupply;
        // balanceOf[msg.sender] = totalSupply;
        // (option C: leave all commented — no initial mint)

        name = tokenName;
        symbol = tokenSymbol;
    }

    function _transfer(address _from, address _to, uint256 _value) internal {
        // Given guards: no burning to the zero address, sender has enough, and
        // the recipient's balance won't overflow.
        require(_to != address(0x0));
        require(balanceOf[_from] >= _value);
        require(balanceOf[_to] + _value >= balanceOf[_to]);

        uint256 previousBalances = balanceOf[_from] + balanceOf[_to];

        /* ─── Q2: take the tokens FROM the sender. ────────────────────────────
           A) balanceOf[_from] -= _value;  — debits the sender's ledger entry.
           B) balanceOf[_to]  -= _value;  — debits the recipient's ledger entry.
           C) leave blank — no account is debited.
           UNCOMMENT EXACTLY ONE: */
        // balanceOf[_from] -= _value;
        // balanceOf[_to] -= _value;
        // (option C: leave all commented — sender not debited)

        /* ─── Q3: give the tokens TO the recipient. ───────────────────────────
           A) balanceOf[_to]  += _value;  — credits the recipient's entry.
           B) balanceOf[_from] += _value;  — credits the sender's entry.
           C) leave blank — no account is credited.
           UNCOMMENT EXACTLY ONE: */
        // balanceOf[_to] += _value;
        // balanceOf[_from] += _value;
        // (option C: leave all commented — recipient not credited)

        /* ─── Q4: announce the transfer to the outside world. ─────────────────
           Background: contracts can't push data to UIs, indexers, or exchanges.
           Instead, the EVM lets a contract append an ENTRY TO THE TRANSACTION
           LOG — a cheap, append-only record stored with the receipt. Off-chain
           software (wallets, block explorers, the marketplace's front-end)
           subscribes to these entries to learn "a transfer happened". Log
           entries are write-only for contracts: no contract can ever read them
           back. Solidity exposes exactly one statement for writing one, tied to
           a declared `event` type. Which line is it?
           A) print(_from, _to, _value);
              — writes to standard output. Does such an output stream exist for
                code running on thousands of nodes at once?
           B) log Transfer(_from, _to, _value);
              — "log" names the underlying EVM concept (LOG opcodes). Is it a
                Solidity keyword, though?
           C) emit Transfer(_from, _to, _value);
              — fires the declared Transfer event with these arguments.
           D) leave blank — the balances still change, but the transaction log
              stays empty, so no off-chain observer learns of the transfer.
           UNCOMMENT EXACTLY ONE (warning: not every option compiles — an option
           that fails `forge build` is itself an answer to reject): */
        // print(_from, _to, _value);
        // log Transfer(_from, _to, _value);
        // emit Transfer(_from, _to, _value);
        // (option D: leave all commented — no announcement)

        /* ─── Q5: guard the bookkeeping invariant. ────────────────────────────
           Background: if Q2 and Q3 are right, the SUM of the two parties'
           balances cannot have changed — tokens moved, none were created or
           destroyed. We want to state: "if this ever fails, the CONTRACT ITSELF
           is buggy". Solidity has two built-in checking statements:
             • require(cond, "msg") — for validating INPUTS and EXTERNAL
               conditions (caller's allowance, balances, timing). Reverts with a
               readable Error(string); "the caller did something invalid".
             • assert(cond) — for INTERNAL INVARIANTS that no caller input
               should ever be able to break. Reverts with a Panic(0x01);
               "the code itself is broken". Static-analysis tools try to prove
               asserts can never fire.
           A) require(balanceOf[_from] + balanceOf[_to] == previousBalances, "invariant broken");
              — checks the condition and reverts with a string error, the same
                signal we use when the CALLER passes bad input.
           B) assert(balanceOf[_from] + balanceOf[_to] == previousBalances);
              — checks the condition and reverts with Panic, the signal reserved
                for "this must be a bug in the contract".
           C) check(balanceOf[_from] + balanceOf[_to] == previousBalances);
              — reads nicely; is `check` part of the Solidity language?
           D) verify(balanceOf[_from] + balanceOf[_to] == previousBalances);
              — likewise; is `verify` part of the Solidity language?
           UNCOMMENT EXACTLY ONE (again, not every option compiles): */
        // require(balanceOf[_from] + balanceOf[_to] == previousBalances, "invariant broken");
        // assert(balanceOf[_from] + balanceOf[_to] == previousBalances);
        // check(balanceOf[_from] + balanceOf[_to] == previousBalances);
        // verify(balanceOf[_from] + balanceOf[_to] == previousBalances);
    }

    // Standard EIP-20 `transfer` (given): move the CALLER's own tokens.
    function transfer(address _to, uint256 _value) public returns (bool success) {
        _transfer(msg.sender, _to, _value);
        return true;
    }

    // Standard EIP-20 `transferFrom`: a spender moves someone ELSE's tokens,
    // consuming the allowance that person granted via approve().
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        /* ─── Q6: a spender may only move tokens they were ALLOWED to. ─────────
           Background: `allowance[owner][spender]` is how many tokens `owner`
           approved `spender` to move. Here the spender is `msg.sender`, moving
           `_from`'s tokens.
           A) require(_value <= balanceOf[_from], "Invalid allowance"); — checks
              that the owner HAS the tokens, but not that the caller was ever
              approved to move them.
           B) require(_value <= allowance[_from][msg.sender], "Invalid allowance");
              — checks the amount against what the owner approved this caller
              to spend.
           C) leave blank — no allowance enforcement at all.
           UNCOMMENT EXACTLY ONE: */
        // require(_value <= balanceOf[_from], "Invalid allowance");
        // require(_value <= allowance[_from][msg.sender], "Invalid allowance");
        // (option C: leave all commented — no allowance check)

        // Given: consume the allowance, then move the tokens.
        allowance[_from][msg.sender] -= _value;
        _transfer(_from, _to, _value);
        return true;
    }

    // Standard EIP-20 `approve` (given): grant `_spender` the right to move up
    // to `_value` of the caller's tokens via transferFrom.
    function approve(address _spender, uint256 _value) public returns (bool success) {
        allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }
}
