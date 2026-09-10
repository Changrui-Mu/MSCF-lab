// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {ERC20Wallet} from "src/1-erc20/ERC20Wallet.sol";
import {BasicERC20} from "src/1-erc20/BasicERC20.sol";
import {USDTMock} from "./ERC20WalletTestBase1.sol";

contract Checkpoint1Diagnostics is Test {
    ERC20Wallet wallet;
    BasicERC20 token;
    USDTMock usdt;
    address owner;
    address recipient;

    function setUp() public {
        owner = makeAddr("owner");
        recipient = makeAddr("recipient");

        vm.prank(owner);
        wallet = new ERC20Wallet();

        token = new BasicERC20();
        token.mint(address(wallet), 100e18);
        usdt = new USDTMock(100e6);
        usdt.transfer(address(wallet), 100e6);
    }

    function test_diag_Q1_1_erc20Send() external {
        // Probe 1: does it work on BasicERC20?
        vm.prank(owner);
        try wallet.transferERC20(address(token), recipient, 5e18) {
            if (token.balanceOf(recipient) != 5e18) {
                console2.log("Q1.1 FAIL: transferERC20 returned without revert but recipient balance is 0.");
                console2.log("  You likely picked D -- the low-level call targets `recipient` instead of `token`, so the call hit recipient (no code), returned ok, but moved no tokens. The ledger lives in the TOKEN contract.");
                return;
            }
        } catch (bytes memory err) {
            bytes4 selector = bytes4(err);
            if (selector == bytes4(keccak256("ERC20InsufficientAllowance(address,uint256,uint256)"))) {
                console2.log("Q1.1 FAIL: ERC20InsufficientAllowance revert. You picked C (transferFrom).");
                console2.log("  Misunderstanding: `transferFrom` pulls from the `from` argument's balance using an allowance the spender (wallet) holds. The wallet has no allowance from msg.sender for its own tokens -- wrong primitive entirely. Use `transfer`/`safeTransfer` to move tokens the wallet already owns.");
            } else {
                console2.log("Q1.1 FAIL: unexpected revert on BasicERC20.");
                console2.logBytes(err);
            }
            return;
        }

        // Probe 2: does it work on USDT (no-return-bool)?
        vm.prank(owner);
        try wallet.transferERC20(address(usdt), recipient, 5e6) {
            console2.log("Q1.1 OK: works on BasicERC20 AND USDT. Choice = B (safeTransfer).");
        } catch {
            console2.log("Q1.1 PARTIAL: works on BasicERC20 but reverts on USDT. You picked A (transfer).");
            console2.log("  Misunderstanding: USDT's `transfer` doesn't return a bool. Solidity's high-level `IERC20.transfer` call expects 32 bytes back; getting 0 bytes makes the ABI decoder revert in the caller, even though the storage update landed. Use OpenZeppelin's SafeERC20.safeTransfer which checks return-data length before decoding.");
        }
    }

    function test_diag_Q1_2_erc20Approve() external {
        // Probe 1: BasicERC20 from 0.
        vm.prank(owner);
        try wallet.approveERC20(address(token), recipient, 100e18) {
            if (token.allowance(address(wallet), recipient) == 0) {
                console2.log("Q1.2 FAIL: call succeeded but allowance is 0. You picked D (transfer).");
                console2.log("  Misunderstanding: `transfer` moves tokens, it does NOT set an allowance. Approvals are a separate primitive.");
                return;
            }
            uint256 first = token.allowance(address(wallet), recipient);
            if (first == 100e18) {
                // good so far
            } else {
                console2.log("Q1.2 ?: unexpected allowance after first approve:");
                console2.log(first);
            }
        } catch {
            console2.log("Q1.2 FAIL: revert on first approve from 0. Investigate.");
            return;
        }

        // Probe 2: re-approve from non-zero -- A reverts on USDT.
        // Use USDT for the re-approve probe. (Same 50 -> 70 example as in the source comment.)
        vm.prank(owner);
        try wallet.approveERC20(address(usdt), recipient, 50e6) {} catch {
            console2.log("Q1.2 FAIL: first USDT approve reverted. Unexpected.");
            return;
        }
        vm.prank(owner);
        try wallet.approveERC20(address(usdt), recipient, 70e6) {
            uint256 finalAllowance = usdt.allowance(address(wallet), recipient);
            if (finalAllowance == 70e6) {
                console2.log("Q1.2 OK: re-approve from non-zero works on USDT. Choice = B (forceApprove).");
            } else if (finalAllowance == 50e6 + 70e6) {
                console2.log("Q1.2 FAIL: allowance is sum (50+70=120). You picked C (safeIncreaseAllowance).");
                console2.log("  Misunderstanding: `safeIncreaseAllowance` ADDS to the existing allowance. The fuzz test expects the SET value to equal the second arg, not the sum.");
            }
        } catch {
            console2.log("Q1.2 PARTIAL: re-approve from non-zero reverted on USDT. You picked A (approve).");
            console2.log("  Misunderstanding: USDT forbids approve from non-zero to non-zero (front-running mitigation). Use forceApprove which resets to 0 first.");
        }
    }
}
