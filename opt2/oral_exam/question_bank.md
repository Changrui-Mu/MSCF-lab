# Question 2: SimpleNFTHTLC Oral Check-off - Question Bank (TA only)

**Format.** ~5 minutes per question. Sample **3** per student: draw **2 from
the N-series below** (new, two-contract material) **+ 1 Part A question** about
the HTLC concepts implemented in `remix/SimpleHTLC.sol` and exercised by
`remix/SimpleHTLCChecker.sol`. Students should expect the ETH-contract ideas
to remain fair game. Rotate subsets across students; record who got what.

The lab is all-MCQ (Q1–Q8 in SimpleNFTHTLC.sol) — so the oral is where
students prove they understood *why* the decoys are wrong, not just which
line passes. Each question below notes which MCQ(s) it anchors on; open the
student's submitted file and point at their actual choice when asking.

Style rules: protocol intuition only, concrete attack scenarios, no
code-comprehension; illustrations show the scenario and end in a question.

Scoring: each out of 5; suggested pass bar ≥ 9/15, no question at 0.

---

## N1 — Why must both contracts share the same hash? *(anchors: checker scenario 4)*

**Ask:** Your NFT contract and ETH contract are on two different chains, but
they use the *same* hashlock. Suppose Bob instead locked his ETH under a
different hash, one made from a secret only *he* knows. What can go wrong for
Alice? Why does one shared hash make the sale atomic?

**Rubric (5):**
- 2 — sees the failure: with two different secrets, Bob can collect the NFT
  (revealing *Alice's* secret does that) while never revealing his own, so
  Alice can't open the money box — she loses the NFT and gets nothing
- 2 — states the mechanism: with ONE hash, the *same* action that pays Alice
  publishes the *only* key Bob needs — claiming and enabling-the-other-side
  are physically the same step, not a promise
- 1 — generalizes: "atomic" here means the two transfers are linked by
  information, not by trust or by a third party

**Misconceptions:** "the contracts talk to each other" (they never do — the
only link is the secret); "a trusted service is still needed".

---

## N2 — Who reveals first, and what do they risk? *(anchors: Q4, checker scenario 4)*

**Ask:** Walk me through the happy path of the sale: who moves first at each
step, and at the moment Alice withdraws Bob's ETH, what exactly has she given
up? Could she instead wait, refuse to reveal, and keep both the NFT and the
money?

**Rubric (5):**
- 2 — correct order: locks first (either order), then Alice (the secret
  holder) claims the money — which reveals the secret — then Bob claims the NFT
- 2 — sees that Alice can't have both: to touch the money she MUST publish
  the secret; if she never reveals, both sides just refund after their
  deadlines — she keeps her NFT but gets no money (a no-deal, not a theft)
- 1 — spots Bob's symmetric safety: he risks nothing by locking first,
  because his ETH lock refunds if the secret never appears

**Misconceptions:** "revealing is optional after claiming"; "whoever goes
first is at a disadvantage" (locks with refunds make going first safe).

---

## N3 — Why is the NFT contract's deadline LONGER? *(anchors: Q4, checker scenario 4)*

**Ask:** Alice's NFT contract on one chain expires in 2 hours, but Bob's ETH
contract on the other chain expires in 1 hour. Suppose we flip them — NFT
contract 1 hour, ETH contract 2 hours. Alice waits until just before the ETH
lock's deadline to withdraw the money. What can she pull off?

**Rubric (5):**
- 3 — reconstructs the attack: Alice reveals at the last second of Bob's
  window; by the time Bob tries to reuse the secret in the NFT contract, it
  (shorter window) has already expired — Alice refunds the NFT AND has the
  money. The party who claims *second* needs the *longer* window
- 1 — states the rule: the secret-holder's own lock must outlive the other
  contract by a safety margin
- 1 — connects to the general principle: deadlines are part of the security
  design, not bookkeeping (compare "what if there were no refund at all"
  from the SimpleHTLC bank)

**Misconceptions:** "the deadlines just need to be long enough"; "equal
deadlines are fairest".

---

## N4 — Why can't lock() work like the payable constructor? *(anchors: Q1, Q2)*

**Ask:** Your SimpleHTLC received the ETH when it was created, so the contract
and the ETH arrived in one step. For the NFT you had to `approve` first
and then call `lock()` to *pull* the token in. Why the extra dance? What is
an NFT, physically, that makes "attach it to the transaction" impossible?

**Rubric (5):**
- 3 — the ledger picture: ETH is the chain's native asset (every address has
  a protocol-level balance that can ride along with a call); an NFT is an
  entry in the NFT *contract's* storage, so only that contract can move it,
  and it only will if the current owner authorized the mover — hence
  approve → pull
- 1 — spots the consequence you built: a `locked` flag and a "not locked"
  guard exist here precisely because creating the contract and moving the NFT
  are no longer one atomic step
- 1 — bonus: same reason receiving ERC-20 needs no `receive()` (the wallet
  lab's lesson) — token "arrival" never touches your contract's code

**Misconceptions:** thinking the NFT is "inside" the wallet/contract that
owns it; expecting a payable-style attachment for tokens.

---

## Backup — Where is the authorization for the pull?

**Ask:** In lock(), your contract calls `nft.transferFrom(sender, ...)` and
it works — but if a stranger deployed their own SimpleNFTHTLC pointed at
Alice's token, their lock() would revert. Neither contract contains any
ownership check. Who is rejecting the stranger, and on what basis?

**Rubric (5):** 3 — the NFT contract checks that its caller (the HTLC) was
approved by the token's owner; Alice only ever approved HER instance. 2 —
generalizes: guards can live in the called contract / inherited layer —
"no check visible" ≠ "no check" (same lesson as the auction lab's
transferNFTFrom note). Use as substitute only — overlaps SimpleHTLC Q4.

---

## Backup B2 — The flag nobody strictly needs *(anchors: Q3, Q6, Q8)*

**Ask:** Here is a puzzle from your own lab. An NFT can only leave the
contract once — a second transfer of the same token reverts inside the NFT
contract no matter what. So in a sense the `settled` flag you added in
Q6/Q8 is redundant: the wrong options "work" by accident. Why did we insist
on the explicit flag anyway? What is different for the person calling the
contract, and for someone auditing it?

**Rubric (5):**
- 2 — callers see YOUR error ("already settled") instead of an internal
  OpenZeppelin error — composability and debuggability: other contracts and
  front-ends act on revert reasons
- 2 — auditability: an explicit state machine (locked → settled) can be read
  and checked on its own; "the asset's ownership happens to make double-pay
  impossible" is an accidental invariant that silently breaks when the code
  changes (e.g. switching the asset to ETH or ERC-20, where nothing is
  unique — compare SimpleHTLC, where the flag is load-bearing!)
- 1 — connects to the ETH contract: in SimpleHTLC the same flag is the ONLY
  thing preventing double-payout — the discipline transfers, the accident does
  not
- Misconception: "if the tests pass without it, it isn't needed".
