// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {MultisigWallet} from "src/2-multisig/MultisigWallet.sol";
import "src/2-multisig/interfaces/IMultisigWallet.sol";

contract Checkpoint2Diagnostics is Test {
    address admin1 = makeAddr("admin1");
    address admin2 = makeAddr("admin2");
    address admin3 = makeAddr("admin3");
    address payable recipient = payable(makeAddr("recipient"));
    address attacker = makeAddr("attacker");

    function _admins() internal view returns (address[] memory a) {
        a = new address[](3);
        a[0] = admin1; a[1] = admin2; a[2] = admin3;
    }

    function test_diag_Q2_1_lengthCheck() external {
        // Reject too-few?
        address[] memory two = new address[](2);
        two[0] = admin1; two[1] = admin2;
        try new MultisigWallet(two) {
            console2.log("Q2.1 FAIL: 2-admin deploy succeeded. You picked B (>=2), C (>0), or D (no check).");
            console2.log("  Misunderstanding: the project hardcodes a 2-of-3 policy; the length must equal ADMIN_COUNT (3), not merely be 'enough'.");
            return;
        } catch {}

        address[] memory four = new address[](4);
        four[0] = admin1; four[1] = admin2; four[2] = admin3; four[3] = attacker;
        try new MultisigWallet(four) {
            console2.log("Q2.1 PARTIAL: 4-admin deploy succeeded. You picked B (>=2) or D (no check).");
            return;
        } catch {}

        console2.log("Q2.1 OK: rejects both too-few and too-many. Choice = A.");
    }

    function test_diag_Q2_5_doubleApprove() external {
        MultisigWallet w = new MultisigWallet(_admins());
        bytes memory action = abi.encodeWithSelector(MultisigWallet.transferEth.selector, recipient, 1 ether);
        vm.prank(admin1); w.approve(action);
        vm.prank(admin1);
        try w.approve(action) {
            console2.log("Q2.5 FAIL: admin1 approved twice. You picked B, C, or D.");
            console2.log("  Misunderstanding: the guard must check whether THIS admin already approved THIS action (approvalsBy[h][msg.sender]). Other conditions (threshold reached, action executed) don't catch the second-approval-by-same-admin case.");
        } catch (bytes memory err) {
            if (bytes4(err) == bytes4(keccak256("AlreadyApproved()"))) {
                console2.log("Q2.5 OK: second approval by same admin reverted with AlreadyApproved. Choice = A.");
            } else {
                console2.log("Q2.5 PARTIAL: reverted but not with AlreadyApproved.");
            }
        }
    }

    function test_diag_Q2_8_autoApprove() external {
        MultisigWallet w = new MultisigWallet(_admins());
        vm.deal(address(w), 10 ether);
        bytes memory action = abi.encodeWithSelector(MultisigWallet.transferEth.selector, recipient, 1 ether);

        // admin1 approves, then admin2 executes -- should succeed (B counts as the 2nd approval).
        vm.prank(admin1); w.approve(action);
        vm.prank(admin2);
        try w.execute(action) {
            if (recipient.balance == 1 ether) {
                console2.log("Q2.8 OK: admin's execute() counted as the 2nd approval. Choice = A.");
            } else {
                console2.log("Q2.8 ?: execute returned ok but recipient not funded.");
            }
        } catch {
            console2.log("Q2.8 FAIL: execute by admin2 reverted (only 1 prior approval).");
            console2.log("  You picked C (skip auto-approve). Misunderstanding: the README requires execute() called by an admin to count as that admin's approval. Without this branch, you need 3 separate calls (approve+approve+execute) instead of the 2-call shortcut (approve+execute).");
        }
    }
}
