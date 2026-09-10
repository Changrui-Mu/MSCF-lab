# Project 4 — Ethereum Wallet : common tasks
# Run `make setup` once on a fresh laptop, then `make test` as you work.

.PHONY: setup build test test0 test1 test2 clean

setup:
	bash setup.sh

build:
	forge build

test:
	forge test

test0:
	forge test --mc Checkpoint0 -vv

test1:
	forge test --mc Checkpoint1 -vv

test2:
	forge test --mc Checkpoint2 -vv

clean:
	forge clean
