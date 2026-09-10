# Question 3 - Ethereum Smart-Contract Wallet

There are two account types in Ethereum:

- EOAs (Externally Owned Accounts): controlled by a private key (that could be held for instance in a hardware wallet)
- contracts: controlled by code

When people talk about wallets, they typically refer to software or hardware that holds private keys and can control any number of EOAs. These EOAs can hold funds, tokens, NFTs, deploy contracts, and generally start transactions. But it is also possible to implement a wallet as a smart contract.  The smart contract wallet sends and received assets based on a hard-coded access control logic.

In this project you will be building such a smart contract wallet, which is initially trivial, but we will progressively add more features to it to make the notion of _programmable money_ more tangible.

This project consists of three required checkpoints. Each checkpoint has some required functionality for you to implement. It also comes with Solidity unit tests that check if your contract meets the requirements.


```
# Your implementation and provided interfaces
src
├── 0-basic                 # Checkpoint 0
│   ├── BasicWallet.sol     # your code goes here
│   └── interfaces
│       └── IWallet.sol
├── 1-erc20                 # Checkpoint 1
│   ├── BasicERC20.sol
│   ├── ERC20Wallet.sol     # your code goes here
│   └── interfaces
│       └── IWallet.sol
└── 2-multisig              # Checkpoint 2
    ├── MultisigWallet.sol  # your code goes here
    └── interfaces
        └── MultisigWallet.sol


# implementations should pass these tests
test
├── 0-basic
│   └── BasicWallet.t.sol
├── 1-erc20
│   └── ERC20Wallet.t.sol
└── 2-multisig
    └── MultisigWallet.t.sol
```


## Quickstart: set up your environment

A Solidity/Foundry project has no Python virtual environment. The equivalent
"environment" is the Foundry toolchain (`forge`/`cast`/`anvil`) plus the
project-local dependency libraries under `lib/`. A setup script provisions all
of this for you, with pinned versions so everyone's build is identical:

```sh
# from the project root (macOS, Linux, or Windows via WSL/Git Bash)
bash setup.sh
```

The script will:
1. install Foundry (via `foundryup`) if it isn't already on your machine,
2. fetch the pinned dependencies (`forge-std v1.11.0`, `OpenZeppelin v5.4.0`) into `lib/`,
3. build the project and run the test suite as a sanity check.

It is safe to re-run. If you prefer `make`: `make setup`, then `make test0` /
`make test1` / `make test2` as you work through the checkpoints. The tests are
expected to fail until you fill in the answers — that's the point.

If you'd rather install everything by hand, follow the manual steps below.

## Getting started: installing Foundry

For CLI/Solidity only development, we will be using Foundry. Follow instructions at [getfoundry.sh](http://getfoundry.sh):

```sh
# first, download the foundry installer, foundryup
curl -L https://foundry.paradigm.xyz | bash

# then run it to install forge, cast, anvil, etc
foundryup

# then fetch the pinned dependencies into lib/
forge install foundry-rs/forge-std@v1.11.0
forge install OpenZeppelin/openzeppelin-contracts@v5.4.0
```

Foundry's job is to let us:
- build our Solidity source code (that includes getting and invoking the right `solc` version, installing libraries, etc.)
- run unit and fuzz tests, also written in Solidity
- measure the performance of our code (in gas)
- deploy contracts using scripts


### Optional (not needed for this project)

Scaffold-eth2 can provide you with a web app that lets you interact with the contract visually or with JavaScript:

- install the requirements at https://docs.scaffoldeth.io/quick-start/installation
- run `npx create-eth@latest`
- pick `foundry` as the Solidity framework

The rest of this document will assume a Foundry-only minimal setup, with unit tests written in Solidity and no need for Node or any of the JavaScript ecosystem.


## Checkpoint 0: basic ownership and handling native currency

Implement a smart contract in [BasicWallet.sol](src/0-basic/BasicWallet.sol) such that:
- it has an `owner() public view return(address)` method that returns the current owner of the wallet
- the default value for `owner` is the address who deployed the contract
- it can receive ether from other addresses
- it can send ether to other addresses

Your code should pass the tests in [BasicWallet.t.sol](test/0-basic/BasicWallet.t.sol).
We suggest studying the testing code carefully to learn what is expected of your code.

You can run these tests with:

```sh
# these will fail initially, they run against your BasicWallet.sol implementation
forge test --match-contract Checkpoint0
```

Follow up questions (please submit your answers):
- what happens when call `transferEth` with an amount greater than the contract’s balance?
- what happens when the `recipient` of a transfer does not exist?
- what happens when the `recipient` of a transfer is a contract?
- why do we use `msg.sender` and not `tx.origin` to perform the authorization check?
- does `owner` have to be an EOA? if not, how?
- what happens if we lose access to the key that controls `owner`?
- why do we transfer ether out of the contract with a low level call and not Solidity’s `transfer`?
- what happens if we send ERC-20 tokens (e.g. USDC) to our wallet address?

References:
- https://docs.soliditylang.org/en/v0.8.30/security-considerations.html#sending-and-receiving-ether
- https://docs.soliditylang.org/en/v0.8.30/security-considerations.html#tx-origin
- https://diligence.consensys.io/blog/2019/09/stop-using-soliditys-transfer-now/
- https://gist.github.com/0xkarmacoma/4f206a46dedc6da6808c1ccdef3262d0


## Checkpoint 1: handling ERC-20 tokens

Implement a smart contract in [ERC20Wallet.sol](src/1-erc20/ERC20Wallet.sol) such that:
- it keeps everything the checkpoint 0 wallet could do: an owner, receiving ETH, and owner-only ETH transfers
- it can receive ERC-20 tokens (hint: not much to do here)
- it can transfer tokens
- it can manage token approvals

The format changes here: the parts you already solved in checkpoint 0 are no
longer multiple-choice — you write them yourself (they are marked
`>>> YOUR CODE (k/5)` in the source). Only the two decisions that are genuinely
new to ERC-20 (how to transfer a token, how to set an allowance) remain as
MCQs. Before writing any code, read the header comment in `ERC20Wallet.sol` —
it explains the key conceptual difference between ETH and ERC-20 balances
(native balance vs. an entry in the token contract's ledger), and everything
in this checkpoint follows from it.

Your code should pass the tests in [ERC20Wallet.t.sol](test/1-erc20/ERC20Wallet.t.sol). If you look at the deceptively simple ERC-20 token standard, you may think there is not much to it, but the tests showcase some quirks you may encounter with real tokens in the wild. We suggest studying the testing code carefully to learn what is expected of your code.

You can run the tests with:

```sh
# these will fail initially, they run against your ERC20Wallet.sol implementation
forge test --match-contract Checkpoint1
```

Follow-up questions (please submit your answers):
- what would happen if we didn't handle token quirks properly?
- how would we know about ERC-20 tokens owned by the wallet? (e.g. to display in a UI)
- what about `decimals()`? does the wallet need to be concerned with these?

References:
- https://eips.ethereum.org/EIPS/eip-20
- https://ethereum.org/developers/docs/standards/tokens/erc-20/
- https://github.com/d-xo/weird-erc20
- https://andrej.hashnode.dev/integrating-arbitrary-erc-20-tokens
- https://docs.openzeppelin.com/contracts/5.x/api/token/erc20#SafeERC20
- USDT token contract: https://etherscan.io/address/0xdac17f958d2ee523a2206206994597c13d831ec7#code


## Checkpoint 2: basic multisig

A limitation of our current setup is that a wallet owned by a single EOA has all the same limitations as the EOA itself:
- if the private key for the EOA is lost, then control over the smart contract is lost (including all its assets)
- if the private key for the EOA is compromised, the hacker instantly gets access to all the assets in the smart contract (in addition to the assets in the EOA itself)

But the real power of a smart contract wallet is that it can have more complex authorization logic. For instance, instead of relying on a single EOA, it could use different setups:
- 1-of-2: 2 admin addresses (e.g. a hot wallet and a hardware wallet), any address can approve transactions. Works against lost keys, but not compromised keys.
- 2-of-2: 2 admin addresses required (e.g. desktop wallet + mobile wallet for confirmation) for every transaction. Works against compromised keys, but increases the risk to lose a key.
- 2-of-3, 3-of-5, etc: addresses both risks, but adds complexity

For this checkpoint, we will focus on hardcoding a simple 2-of-3 policy with a fixed set of admins. For simplicity, we can also store authorizations on chain (in the real world, it would be better and cheaper to use offchain signatures).

Implement the following changes:
- pass 3 admin addresses in the constructor instead of relying on the deployer
- implement an `approve(bytes)` function that admins can invoke to authorize an action encoded in `bytes` and emits an `Approved(address admin, bytes action)` event
- implement an `execute(bytes)` function that anyone can invoke (!) to execute the action encoded in `bytes` as long as it is approved by 2 or more admins, and also counts as an approval when invoked by an admin

Because `execute(bytes)` counts as an approval when invoked by an admin, the following 2 flows should be supported:

```
approve(bytes) // by admin1
approve(bytes) // by admin2
execute(bytes) // by anyone

or:

approve(bytes) // by admin1
execute(bytes) // by admin2
```

Your code should pass the tests in [MultisigWallet.t.sol](test/2-multisig/MultisigWallet.t.sol).
We suggest studying the testing code carefully to learn what is expected of your code.
You can run the tests with:

```sh
forge test --match-contract Checkpoint2
```

Follow-up questions (please submit your answers):
- how would you implement flexible policies (updatable owners, updatable threshold)? think about failure scenarios like `threshold == 0` or `threshold > admins.length`
- what's the point of emitting events in `approve` and `execute`?
