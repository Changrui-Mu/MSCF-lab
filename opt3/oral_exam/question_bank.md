# Question 1: NFT Marketplace Auction (folder: lab/opt3) Oral Check-off - Question Bank (TA only)

**Format.** ~5 minutes per question. Sample **3** per student from the bank
below; rotate subsets across students and record who got what. Each question
starts from the student's choices in Question 1 (Q1-Q20) or their Checkpoint 5
implementation — open the submitted file and point at the relevant choice or
state update when asking.

Style rules: protocol intuition only, concrete attack/accounting scenarios, no
code-comprehension trivia. Ask the student to trace custody and balances aloud.

Scoring: each out of 5; suggested pass bar **≥ 9/15, with no question at 0**.

---

## A1 — Approval is a budget, not a payment *(anchors: Q6, Q14)*

**Ask:** Maya has 500 PAY. She calls `approve(marketplace, 300)` and then bids
200. A stranger calls the token's `transferFrom(Maya, stranger, 100)`, and
later the marketplace tries to pull another 150 from Maya. Which calls should
succeed? Where are the tokens after the approval and after the bid, and why is
checking Maya's balance not a substitute for checking allowance?

**Rubric (5):**

- 2 — approval alone moves nothing: Maya still holds 500; it records that the
  marketplace, and only that spender, may move up to 300 on her behalf
- 2 — the stranger's pull fails; the 200 bid pull succeeds and leaves Maya
  with 300, the marketplace with 200, and marketplace allowance 100; a later
  150 pull fails because it exceeds the remaining allowance
- 1 — explains the distinction: balance answers "does the owner have it?";
  allowance answers "did the owner authorize this caller to move it?"

**Misconceptions:** "approve sends 300 into escrow"; "any caller may spend an
approved amount"; "the marketplace can pull 300 on every call forever".

---

## A2 — Approved is not escrowed *(anchors: Q7, Q8, Q9, Q10, Q11)*

**Ask:** Lina owns NFT #7 and approves the marketplace for that token, but she
has not called `createAuction` yet. She then tries to transfer #7 to a friend.
Compare that with the moment after `createAuction` succeeds. Who owns #7 in
each case, who can move it, and why do we need both an approval check and an
actual custody transfer when opening the auction?

**Rubric (5):**

- 2 — before creation Lina still owns #7; approval is authority, not custody,
  so she can transfer it and that transfer clears/invalidates the token-specific
  approval
- 2 — successful creation pulls #7 from Lina into the marketplace; escrow now
  prevents Lina from selling or transferring the same asset during the auction,
  while the marketplace can later deliver or refund it
- 1 — connects the guards: Q9 establishes the caller is the owner, Q10 checks
  that this marketplace is authorized, and Q11 is the step that actually locks
  the NFT (using Q8's correctly directed inherited ERC-721 transfer)

**Misconceptions:** "approve changes the owner"; "the NFT is escrowed as soon
as approval is mined"; "checking ownership alone lets the marketplace pull it".

---

## A3 — Follow the money through an outbid *(anchors: Q12, Q13, Q14, Q15)*

**Ask:** The standing price is 50. Alice bids 100, then Bob bids 160. Immediately
after Bob's transaction, list Alice's, Bob's, and the marketplace's net token
changes from before either bid. What breaks if Alice is refunded 160 instead of
100, or is not refunded at all? Why must the refund use the old winner and
price before those fields are overwritten?

**Rubric (5):**

- 2 — traces the intended balances: Alice's 100 is pulled then returned, so her
  net change is 0; Bob is down 160; marketplace holds exactly Bob's 160
- 2 — refunding Alice 160 pays her 60 she never escrowed (using Bob's funds and
  leaving only 100 for settlement); no refund strands Alice's 100 and makes the
  marketplace hold 260 even though only one live bid backs the auction
- 1 — the refund must use the displaced `currentBidOwner/currentBidPrice`
  before replacement; bids must strictly increase, and excluding the seller
  prevents the seller from manufacturing the standing price

**Misconceptions:** "the marketplace should retain every historical bid";
"refund the previous bidder with the incoming bid amount"; "a tied bid can
replace the leader harmlessly".

---

## A4 — Auction zero is selling NFT seven *(anchor: Q18)*

**Ask:** A marketplace's first listing has auction index 0, but it sells NFT
token id 7. The seller also owns NFT #0. After bidding closes, settlement passes
the auction index where the ERC-721 transfer expects a token id. What happens?
Could tests accidentally miss this bug, and what should each number be used to
look up?

**Rubric (5):**

- 2 — distinguishes the namespaces: auction index 0 selects the marketplace's
  auction record; `auction.nftId == 7` identifies the asset inside the NFT
  collection contract
- 2 — in this scenario passing 0 reverts because the marketplace does not own
  NFT #0; more generally it could move the wrong NFT if the marketplace did
  own it — either way NFT #7 does not reach the winner
- 1 — a test where auction index happens to equal token id passes by accident;
  robust tests deliberately make them different

**Misconceptions:** "the first auction always sells the first NFT"; "IDs are
globally unique across contracts"; "the array index is merely another name for
the NFT id".

---

## A5 — The winner disappears after the deadline *(anchors: Q16, Q17, Q19, Q20)*

**Ask:** Alice wins an auction, but after the deadline she goes offline and
never calls `claimNFT`. If only the winner could settle, what remains stuck?
Explain the seller-side settlement path, who receives each asset, and what must
stop the seller from instead using the no-bid refund or settling a second time.

**Rubric (5):**

- 2 — without seller-triggered settlement, both the NFT and winning ERC-20 bid
  can remain escrowed forever; a deadline alone does not move assets
- 2 — after close the seller may trigger settlement, but the NFT still goes to
  the recorded winner and the payment goes to the seller; caller and beneficiary
  need not be the same
- 1 — refund is valid only when `currentBidOwner` is zero/no bid exists, and one
  shared settled state must block every later claim/refund path

**Misconceptions:** "the contract automatically runs at the deadline"; "if the
seller calls, the NFT returns to the seller"; "each settlement entry point may
have its own one-time flag".

---

## A6 — Where did all 200 tokens go? *(anchor: Checkpoint 5)*

**Ask:** The reserve is 50. Alice bids 100 and is refunded when Bob bids 200.
At settlement, Bob is the winner. Starting just before Bob's bid, trace every
token transfer through settlement. What should `secondBidPrice` be, how much
does the seller receive, how much returns to Bob, and why must the marketplace
finish at zero? Then tell me the single-bid version.

**Rubric (5):**

- 2 — Bob escrows 200 and Alice receives her full 100 refund; the displaced
  highest price 100 becomes `secondBidPrice`
- 2 — seller receives 100 and Bob receives 200 − 100 = 100, so Bob's net cost
  is the second price and the auction's escrow is exhausted exactly
- 1 — with one bid, second price remains the reserve 50: seller gets 50 and the
  sole bidder gets back their bid minus 50

**Misconceptions:** "the seller receives the highest bid"; "the winner's refund
comes from the loser"; "second price starts at zero"; "a leftover marketplace
balance is harmless protocol revenue".

---

## Backup B1 — Tokens moved, but nobody heard about it *(anchors: Q1, Q2, Q3, Q4, Q5)*

**Ask:** A payment token correctly gives the deployer its decimals-scaled supply
and transfers 40 from Alice to Bob by subtracting 40 from Alice and adding 40
to Bob, but emits no `Transfer` event. Has on-chain ownership changed? What do
wallets and indexers observe, and what invariant should still hold across the
two balances? Classify a failure of that invariant versus Alice lacking funds.

**Rubric (5):**

- 2 — balances are authoritative, so the transfer happened on-chain even
  without the event; off-chain software following logs may miss it or show
  stale/incomplete history
- 2 — Alice + Bob's combined balance is unchanged by a pure transfer; debiting
  the wrong side, crediting the wrong side, or omitting one update violates
  conservation even if the initial supply was minted correctly
- 1 — insufficient funds is an external/input condition suited to `require`;
  conservation failure after valid bookkeeping is an internal bug/invariant
  suited to `assert`

**Misconceptions:** "events perform the transfer"; "contracts can read old logs
to recover balances"; "assert and require communicate the same kind of failure".

---

## Backup B2 — Three callers, three different rights *(anchors: Q6, Q9, Q13, Q17)*

**Ask:** A seller owns the NFT, a bidder owns payment tokens, and the marketplace
coordinates the auction. For listing, bidding, and claiming, name the direct
caller whose authority matters and the separate asset permission involved.
Why would replacing these checks with `tx.origin` or a generic "has enough
balance" check blur security boundaries?

**Rubric (5):**

- 2 — listing authenticates the direct NFT owner and requires that owner to
  approve the marketplace for the NFT; bidding authenticates a non-seller
  bidder and consumes that bidder's ERC-20 allowance granted to the marketplace
- 2 — claiming authenticates the recorded winning bidder (or the seller may
  invoke the distinct liveness path), while settlement transfers only the
  assets already held in marketplace escrow
- 1 — `msg.sender` identifies the immediate actor/spender; `tx.origin` can let a
  malicious intermediary borrow the user's identity, and balance proves means,
  not consent

**Misconceptions:** "ownership automatically approves the marketplace";
"having enough tokens authorizes any spender"; "tx.origin is safer because it
always identifies the human".
