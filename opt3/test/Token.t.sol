// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "src/ERC20.sol";

/// CHECKPOINT 0 — ERC-20 payment token (Q1–Q6)
/// Run with:  forge test --mc Checkpoint0
contract Checkpoint0Token is Test {
    ERC20 internal token;
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal carol = makeAddr("carol");

    // Mirror of the token's Transfer event so vm.expectEmit can match it (Q4).
    event Transfer(address indexed from, address indexed to, uint256 value);

    function setUp() public {
        // The test contract deploys the token and therefore holds the supply.
        token = new ERC20(1_000_000, "Pay Token", "PAY");
    }

    // Q1: the deployer is credited the full, decimals-scaled supply.
    function test_DeployerHoldsFullSupply() public view {
        assertEq(token.totalSupply(), 1_000_000 ether, "total supply wrong");
        assertEq(token.balanceOf(address(this)), 1_000_000 ether, "deployer was not credited the supply");
    }

    // Q2 + Q3: a transfer debits the sender and credits the recipient.
    function test_TransferMovesTokens() public {
        token.transfer(alice, 100 ether);
        assertEq(token.balanceOf(alice), 100 ether, "recipient not credited (Q3)");
        assertEq(token.balanceOf(address(this)), 1_000_000 ether - 100 ether, "sender not debited (Q2)");
    }

    // Q4: every transfer must announce itself in the transaction log so
    // off-chain software (wallets, indexers, the auction UI) can see it.
    function test_TransferEmitsEvent() public {
        vm.expectEmit(true, true, false, true);
        emit Transfer(address(this), alice, 100 ether);
        token.transfer(alice, 100 ether);
    }

    // Q6: transferFrom respects the approved allowance and consumes it.
    function test_TransferFromUsesAllowance() public {
        token.transfer(alice, 100 ether);
        vm.prank(alice);
        token.approve(bob, 40 ether);

        vm.prank(bob);
        token.transferFrom(alice, carol, 40 ether);

        assertEq(token.balanceOf(carol), 40 ether, "carol not paid");
        assertEq(token.balanceOf(alice), 60 ether, "alice not debited");
        assertEq(token.allowance(alice, bob), 0, "allowance not consumed");
    }

    // Q6: without an allowance, transferFrom must be rejected.
    function test_RevertWhen_NoAllowance() public {
        token.transfer(alice, 100 ether);
        vm.prank(bob);
        vm.expectRevert("Invalid allowance");
        token.transferFrom(alice, carol, 10 ether);
    }
}
