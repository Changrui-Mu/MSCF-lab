// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {BasicWallet} from "src/0-basic/BasicWallet.sol";
import {IBasicWallet} from "src/0-basic/interfaces/IBasicWallet.sol";

// Helper recipient whose receive() does ~5000 gas of work — defeats `.transfer` (2300-gas stipend).
contract HungryReceiver {
    uint256[] public log;
    receive() external payable {
        // Force three SSTOREs (~22k gas) so .transfer/.send reverts.
        log.push(1);
        log.push(2);
        log.push(3);
    }
}

contract Checkpoint0Diagnostics is Test {
    BasicWallet wallet;
    address owner;
    address payable plainRecipient;
    HungryReceiver hungry;

    function setUp() public {
        owner = makeAddr("owner");
        plainRecipient = payable(makeAddr("plain"));
        hungry = new HungryReceiver();

        vm.prank(owner);
        wallet = new BasicWallet();
        vm.deal(address(wallet), 10 ether);
    }

    function test_diag_Q0_1_owner() external view {
        address o = wallet.owner();
        if (o == owner) {
            console2.log("Q0.1 OK: owner set to deployer (msg.sender). Choice = B.");
        } else if (o == address(0)) {
            console2.log("Q0.1 FAIL: owner is address(0). You picked D (no assignment).");
            console2.log("  Misunderstanding: state variables don't auto-populate. Without a constructor write, owner stays at its default zero value, and every authz check then fails.");
        } else if (o == address(wallet)) {
            console2.log("Q0.1 FAIL: owner is the wallet itself. You picked C (address(this)).");
            console2.log("  Misunderstanding: address(this) is the wallet contract's own address, not the deployer. No EOA can ever satisfy `msg.sender == owner`, so nothing can authorize transfers.");
        } else {
            console2.log("Q0.1 ?: owner is set but not to the test's `owner` address. If you picked A (tx.origin) in this test harness, tx.origin and msg.sender are the same during the prank, so this branch usually means a custom edit. Check MCQ-ANSWERS.md for A vs B.");
        }
    }

    function test_diag_Q0_2_receive() external {
        uint256 before = address(wallet).balance;
        (bool ok,) = address(wallet).call{value: 1 ether}("");
        if (ok && address(wallet).balance == before + 1 ether) {
            console2.log("Q0.2 OK: wallet accepts plain ETH. (Either A receive() or B fallback() would pass this probe.)");
            console2.log("  Note: A is the intended primitive for plain transfers. B (fallback) works too but is meant for unmatched function calls.");
        } else if (!ok) {
            console2.log("Q0.2 FAIL: plain ETH send reverted. You picked C (named deposit) or D (nothing).");
            console2.log("  Misunderstanding: a contract with no receive() and no payable fallback() REJECTS empty-calldata ETH sends. Named functions like deposit() only catch calls that include their selector.");
        }
    }

    function test_diag_Q0_3_authz() external {
        // Try as a non-owner. Should revert with NotAuthorized().
        address attacker = makeAddr("attacker");
        uint256 recipientBefore = plainRecipient.balance;
        vm.prank(attacker);
        try wallet.transferEth(plainRecipient, 0.1 ether) {
            if (plainRecipient.balance > recipientBefore) {
                console2.log("Q0.3 FAIL: attacker succeeded at transferEth and ETH moved. You picked D (no check).");
                console2.log("  Misunderstanding: without an explicit authz check, ANY caller can drain the wallet.");
            } else {
                console2.log("Q0.3 FAIL: attacker's call SUCCEEDED but no ETH moved. You picked C (silent return).");
                console2.log("  Misunderstanding: `return` blocks the transfer but fails SILENTLY -- the unauthorized transaction still succeeds. Callers/UIs/tests can't tell rejection from success. Fail loudly: revert NotAuthorized().");
            }
            return;
        } catch (bytes memory err) {
            bytes4 selector = bytes4(err);
            if (selector == bytes4(keccak256("NotAuthorized()"))) {
                console2.log("Q0.3 OK: revert with NotAuthorized(). Choice = A.");
            } else {
                console2.log("Q0.3 ?: reverted, but NOT with NotAuthorized(). Custom edit? Check MCQ-ANSWERS.md.");
                console2.logBytes(err);
            }
        }
        // tx.origin distractor: under vm.prank, msg.sender = attacker but tx.origin = default(Foundry test contract). To detect B (tx.origin), call via a helper contract that re-enters the wallet.
        // (Optional: leave the simpler check above; B mostly behaves like A in this harness.)
    }

    function test_diag_Q0_4_ethSend() external {
        vm.deal(address(wallet), 10 ether);

        // Probe 1: send to a hungry receiver. Only B (call) succeeds.
        vm.prank(owner);
        try wallet.transferEth(payable(address(hungry)), 0.1 ether) {
            if (address(hungry).balance == 0.1 ether) {
                console2.log("Q0.4 OK: low-level call forwarded enough gas to a hungry receiver. Choice = B.");
            } else {
                console2.log("Q0.4 ?: call returned ok but balance not credited. Investigate (possibly C/send returned bool false silently).");
            }
        } catch {
            console2.log(unicode"Q0.4 FAIL: revert on hungry receiver. You picked A (transfer) — 2300-gas stipend isn't enough.");
            console2.log("  Misunderstanding: `.transfer()` and `.send()` forward only 2300 gas. Any recipient whose receive() does meaningful work (SSTORE, external call) will out-of-gas. Use low-level call which forwards all remaining gas.");
            return;
        }

        // Probe 2: detect D (selfdestruct) — after one send, the wallet has no code.
        if (address(wallet).code.length == 0) {
            console2.log("Q0.4 FAIL: wallet contract has no code after one transfer. You picked D (selfdestruct).");
            console2.log("  Misunderstanding: selfdestruct DESTROYS the contract. After one call, the wallet is permanently bricked.");
        }
    }
}
