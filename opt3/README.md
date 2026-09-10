# Question 1 - NFT Marketplace Auction (MCQ edition)

A guided, bottom-up build of an on-chain **English auction** for NFTs, built for
15-435 / 635 / 735 / 18-435 / 635 (Smart Contracts). Instead of writing the code
from scratch, you complete it by making **twenty** multiple-choice decisions
(Q1–Q20) across three contracts — then, in the final checkpoint, you **write
code yourself** to convert the marketplace into a **second-price (Vickrey)
auction**. Budget ~75 minutes. The position of the correct option (A/B/C/D)
carries **no signal**, and a few options don't even compile — reasoning about
each option is the exercise.

Adapted to Foundry from the upstream Hardhat project
[HugoBrunet13/NFT-Marketplace-Auction](https://github.com/HugoBrunet13/NFT-Marketplace-Auction).

## The story

A seller lists an **ERC-721 NFT** for sale by opening an auction and naming the
**ERC-20 token** bidders must pay in. When the auction opens, the NFT is moved
into the marketplace's custody (escrow). Buyers place bids; each bid's tokens
are **locked in the marketplace**, and whenever someone is out-bid, their tokens
are **refunded**. After the deadline, the **winner claims the NFT** (which pays
the seller), or — if nobody bid — the **seller reclaims the NFT**.

You build this from the ground up: first the **token** that holds value, then
the **NFT** that represents the item, then the **marketplace** that escrows both
sides of the trade until settlement — and finally a marketplace with a smarter
**payment rule**.

## What you edit

Four files, in order. The first three contain questions with candidate lines,
all commented out, each with a plain-English note. **Uncomment the single
correct line** (remove the leading `// `); leave the rest commented. For options
described as "leave all commented", do nothing. The fourth file has three
`>>> YOUR CODE` blanks you fill in with your own code.

```
src
├── ERC20.sol                  # Checkpoint 0 — payment token       (Q1-Q6)
├── NFTCollection.sol          # Checkpoint 1 — NFT collection      (Q7-Q8)
├── Marketplace.sol            # Checkpoints 2-4 — the marketplace  (Q9-Q20)
└── SecondPriceMarketplace.sol # Checkpoint 5 — write-it-yourself

test
├── Token.t.sol                # Checkpoint 0
├── NFT.t.sol                  # Checkpoint 1
├── MarketplaceTestBase.sol    # shared fixtures
├── CreateAuction.t.sol        # Checkpoint 2
├── Bidding.t.sol              # Checkpoint 3
├── Settlement.t.sol           # Checkpoint 4
└── SecondPrice.t.sol          # Checkpoint 5
```

Do not edit the files under `test/` — they set up the scenarios and check your
work. Solve the checkpoints **in order**: the marketplace tests rely on a
correctly-implemented token and NFT.

## Quickstart

```sh
# from the lab/opt3/ directory (macOS, Linux, or Windows via WSL/Git Bash)
bash setup.sh
```

The script installs Foundry (if missing), fetches the pinned dependencies
(`forge-std v1.11.0`, `OpenZeppelin v5.4.0`) into `lib/`, builds, and runs the
suite. It is safe to re-run. If you prefer `make`: `make setup`, then `make
test0` … `make test5` as you work. Tests are expected to fail until you fill in
the answers — that's the point.

## The six checkpoints

### Checkpoint 0 — `ERC20.sol`, the payment token (Q1–Q6)

The currency bidders pay with, which the marketplace escrows. The file header
also explains what is fixed by the EIP-20 **standard** (the public interface)
versus what is up to the implementer (everything inside — including the bugs
you're avoiding).

- **Q1** — credit the deployer the full (decimals-scaled) initial supply.
- **Q2** — debit the sender inside `_transfer`.
- **Q3** — credit the recipient inside `_transfer`.
- **Q4** — announce the transfer to the off-chain world (careful: some options
  don't compile).
- **Q5** — guard the bookkeeping invariant with the right checking statement
  (`assert` vs `require` — and two impostors).
- **Q6** — `transferFrom` must enforce the spender's allowance.

```sh
forge test --mc Checkpoint0
```

### Checkpoint 1 — `NFTCollection.sol`, the NFT (Q7–Q8)

The ERC-721 items put up for auction. Note how much is **inherited** from
OpenZeppelin's `ERC721` (ownership, approvals, safe transfers, events) — the
file header lists it; this file only adds minting and a transfer wrapper.

- **Q7** — mint each new NFT to its caller.
- **Q8** — `transferNFTFrom` moves the token in the requested direction.

```sh
forge test --mc Checkpoint1
```

### Checkpoint 2 — `createAuction` (Q9–Q11)

Open an auction and move the NFT into escrow.

- **Q9** — verify the caller actually owns the NFT.
- **Q10** — verify the marketplace has been approved to move the NFT.
- **Q11** — pull the NFT into the marketplace's custody.

```sh
forge test --mc Checkpoint2
```

### Checkpoint 3 — `bid` (Q12–Q15)

Place a bid, escrowing the bidder's tokens and refunding whoever was out-bid.

- **Q12** — a new bid must strictly beat the standing price.
- **Q13** — the seller may not bid on their own auction.
- **Q14** — escrow the bidder's tokens (`transferFrom` pull).
- **Q15** — refund the previous highest bidder their exact escrowed amount.

```sh
forge test --mc Checkpoint3
```

### Checkpoint 4 — `claimNFT` / `refund` (Q16–Q20)

Settle the auction after the deadline.

- **Q16** — claiming is only allowed once the auction has closed.
- **Q17** — only the winning bidder may claim the NFT.
- **Q18** — transfer the **correct token id** (`auction.nftId`, not the auction
  index — a real bug in the upstream repo).
- **Q19** — pay the escrowed tokens to the seller.
- **Q20** — `refund` is only valid when there were **no bids**.

```sh
forge test --mc Checkpoint4
```

### Checkpoint 5 — `SecondPriceMarketplace.sol`, the Vickrey twist (write-it-yourself)

The finale changes the **payment rule**: the highest bidder still wins, but pays
only the **second-highest price** — which makes truthful bidding the dominant
strategy (this is the Vickrey auction from auction theory; eBay's proxy bidding
is the household example). The contract is given, mirroring the marketplace you
just completed; **you write the three lines that differ**:

1. maintain the second-highest price as bids arrive,
2. pay the seller the *second* price at settlement,
3. refund the winner the difference between their bid and the second price.

The tests enforce money conservation: after settlement the marketplace must
hold exactly zero tokens. There is no multiple choice here — read the header
comment in the file for the economics and a worked example, then write the code.

```sh
forge test --mc Checkpoint5
```

## How grading works

A `[PASS]` means your selected options produced the correct on-chain behavior.
When a test fails, read the assertion message — it names the misconception
(e.g. "previous bidder not refunded exactly", "seller must receive the SECOND
price") — then revisit the matching question's explanation in the source. If
`forge build` itself fails, the option you uncommented isn't valid Solidity —
that, too, is an answer to reject.

## Mapping to lecture

This lab extends the course's **escrow** and **commitment** material: the
marketplace is a trusted intermediary that holds both the NFT and the bid tokens
until the auction's settlement conditions are met. Building the token and NFT
first makes concrete what "value" and "ownership" mean before the marketplace
moves them around. Q15 (refund-on-outbid) and Q20 (no-refund-after-bid) are
where most real auction bugs live — they decide whether funds and assets can get
stranded or stolen. Checkpoint 5 connects the code to **auction theory**: one
changed payment rule turns strategic bid-shading into truthful bidding.

> The intended answers are in `ANSWER_KEY.md` (instructor copy — remove before
> distributing to students).
