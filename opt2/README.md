# Question 2 - Hash-Time-Locked ETH and NFT Exchange

You will build two contracts for an atomic ETH-for-NFT sale. The contracts are
designed to run on two different chains. All files needed for Question 2 are
already together in `lab/opt2/remix/`.

## Background

A hashed timelock contract (HTLC) locks an asset with a secret and a deadline.
The receiver can claim the asset only by revealing a secret whose sha256 hash
matches the stored hash. If the secret is not revealed before the deadline,
the original sender can take the asset back.

Question 2 applies this pattern twice:

- **Part A - ETH contract:** `SimpleHTLC` locks Bob's ETH for Alice on one
  chain.
- **Part B - NFT contract:** `SimpleNFTHTLC` locks Alice's NFT for Bob on
  another chain.

Both contracts use the **same hash**. When Alice claims Bob's ETH, she reveals
the secret on-chain. Bob can then reuse that secret to claim the NFT. If Alice
never reveals it, both parties recover their assets after the deadlines. The
NFT deadline must be longer so Bob still has time to claim after Alice reveals
the secret near the ETH deadline.

The NFT contract also works differently from the ETH contract. ETH can be sent
when a contract is created, but an NFT is an ownership record inside an ERC-721
contract. Alice must first approve the NFT HTLC and then call `lock()` so it can
move the token from Alice into itself.

The Remix checker creates both contracts in one test environment so it can
show the full sequence. In the intended exchange, the contracts are on two
different chains and do not call each other. The revealed secret links them.

No installation is needed; everything runs in Remix in your browser.

## Setup in Remix

If this is your first lab, read [REMIX_GUIDE.md](../../REMIX_GUIDE.md) first.
Then open `lab/opt2/remix/`, which contains all five required files:

- `SimpleHTLC.sol` - Part A student contract
- `SimpleHTLCChecker.sol` - Part A checker
- `SimpleNFT.sol` - provided ERC-721 contract
- `SimpleNFTHTLC.sol` - Part B student contract
- `SimpleNFTHTLCChecker.sol` - Part B and complete atomic-sale checker

In the **Solidity Compiler** tab, choose version **0.8.20 or newer** and
compile the files. Remix downloads the OpenZeppelin ERC-721 dependency when
needed.

## Part A - ETH HTLC

Open `SimpleHTLC.sol` and complete **TODO 1-7**. The TODOs use two formats:

- **[WRITE]** - write the requested line yourself.
- **[CHOOSE]** - uncomment exactly one of the A/B/C options.

To check Part A:

1. Compile `SimpleHTLC.sol` and `SimpleHTLCChecker.sol`.
2. In **Deploy & Run Transactions**, use the **Remix VM** environment.
3. Deploy `SimpleHTLCChecker`.
4. Enter **3** in the **VALUE** field, select **wei**, and call
   `runAllTests`.
5. Call `isSolved`; it must return **true**.

If a transaction reverts, read the revert reason, fix the named TODO,
recompile, and deploy a fresh checker.

## Part B - NFT HTLC and atomic sale

Open `SimpleNFTHTLC.sol` and answer **Q1-Q8**. Each question gives several
options with a description of its behavior. Uncomment exactly one option per
question. For an explicit "do nothing" option, leaving its candidate lines
commented is the answer.

To check Part B and the complete sale:

1. Make sure your completed `SimpleHTLC.sol` is in the same folder and Part A
   already passes.
2. Compile all five Solidity files in `lab/opt2/remix/`.
3. Deploy `SimpleNFTHTLCChecker` in Remix VM.
4. Enter **1** in the **VALUE** field, select **wei**, and call
   `runAllTests`.
5. Call `isSolved`; it must return **true**.

The checker's final scenario uses your NFT HTLC and ETH HTLC with one secret
and two deadlines. Your submission screenshots should show both checkers,
successful `runAllTests` transactions, and both `isSolved = true` results.

## Grading - oral check-off

There is no written homework for this lab. After both checkers pass, you will
complete a short oral check-off about why the contracts use a shared hash,
different deadlines, approval before moving the NFT, and one-shot settlement.

## Folder map

- `remix/` - all student contracts and checkers for Question 2.
- `oral_exam/` - TA-only question bank.
- `instructor/`, `archive/` - TA-only materials when present.
