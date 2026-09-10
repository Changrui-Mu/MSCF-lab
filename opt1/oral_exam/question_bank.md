# Question 3: Wallet Labs (folder: lab/opt1) Oral Check-off - Question Bank (TA only)

Same format as the HTLC banks: ~5 min each, protocol-intuition style,
concrete attack scenarios, no code-comprehension. Sample per student and
record who got what. Each question starts from choices the student made in
their own MCQ file.

---

## W1 — What breaks if we only require "at least 2 admins"? *(from Q2.1, Mu's request)*

**Ask:** Your multisig hard-codes THRESHOLD = 2 and requires exactly 3
admins. Suppose we relax the constructor to accept "any 2 or more admins"
and someone deploys it with 10 admins. The contract still compiles, all
functions still work. What has quietly changed about the wallet's security?
And what if someone deploys with exactly 2?

**Rubric (5):**
- 2 — sees that "2-of-10" is far weaker than "2-of-3": ANY 2 of 10 keys —
  the attacker needs to compromise 2 people out of a much bigger, easier
  pool; the threshold must scale with the group, it is not an absolute
- 2 — the 2-of-2 case: no fault tolerance — one lost key (not even stolen)
  freezes the money forever; multisig trades off theft-resistance (higher
  threshold) against loss-resistance (lower threshold)
- 1 — conclusion: admin count and threshold are ONE design decision, so a
  constructor that pins one but not the other is a misconfiguration trap
- Misconception: "more admins = more secure" without asking what fraction
  must sign.

---

## W2 — Why does transferEth reject even the admins?

**Ask:** In your multisig, `transferEth` refuses everyone except the wallet
itself — even admin #1 calling it directly gets NotAuthorized. Isn't that
backwards? Walk me through how money actually leaves this wallet, and what
an admin could do if `transferEth` accepted admin callers directly.

**Rubric (5):**
- 2 — reconstructs the intended path: approve ×2 → execute → the wallet
  CALLS ITSELF with the action bytes → self-call passes the gate
- 2 — sees the attack if admins could call directly: one admin alone moves
  the money, and the 2-of-3 ceremony becomes decoration — the gate is what
  FORCES every payment through the threshold check
- 1 — generalizes: authorization should protect the *capability* (moving
  funds), not just the *entry points* people are expected to use
- Misconception: "the owner check is missing on transferEth".

---

## W3 — The phishing wallet *(from Q0.1 + Q0.3's tx.origin trap)*

**Ask:** A student wallet used `tx.origin` for both storing the owner and
authorizing transfers. It passes every everyday test: the owner can pay,
strangers are rejected. Describe, step by step, how this wallet gets
drained — what does the owner have to be tricked into doing, and why does
the wallet let the thief's transfer through?

**Rubric (5):**
- 3 — the chain: owner is lured into calling ANY function of a malicious
  contract (fake airdrop/mint) → that contract calls
  wallet.transferEth(attacker, all) → inside the wallet, tx.origin is still
  the owner → check passes, funds leave
- 1 — states the fix and why it works: msg.sender names the DIRECT caller
  (the malicious contract), which is not the owner → revert
- 1 — the general rule: authenticate your direct caller; tx.origin
  authenticates the human at the far end of someone else's transaction
- Misconception: "the owner would have to sign the malicious transfer
  itself" — they only sign an innocent-looking call.
