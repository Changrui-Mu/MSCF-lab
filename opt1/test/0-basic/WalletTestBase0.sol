// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";

import {IBasicWallet} from "src/0-basic/interfaces/IBasicWallet.sol";

abstract contract WalletTestBase0 is Test {
    IBasicWallet public wallet;

    address public owner;
    address public donator;
    address payable public recipient;
    address public attacker;

    function setUp() public virtual {
        owner = makeAddr("owner");
        donator = makeAddr("donator");
        recipient = payable(makeAddr("recipient"));
        attacker = makeAddr("attacker");
    }

    function test_owned_by_owner() external view {
        assertEq(wallet.owner(), owner);
    }

    function test_can_receive_ether() external {
        // initial balance is 0
        assertEq(address(wallet).balance, 0 ether);

        // when someone sends 1 ether to the wallet contract
        uint256 amount = 1 ether;
        vm.deal(donator, amount);
        vm.prank(donator);
        (bool success,) = payable(address(wallet)).call{value: amount}("");

        // then the transfer succeeds and the balance of the wallet contract has increased by 1 ether
        assertTrue(success);
        assertEq(address(wallet).balance, amount);
    }

    function test_owner_can_transfer_ether() external {
        // initial balance is 1 ether
        vm.deal(address(wallet), 1 ether);

        // when the owner sends some ether
        uint256 amount = 0.1 ether;
        vm.prank(owner);
        wallet.transferEth(recipient, amount);

        // then the transfer succeeds and the recipient is credited
        assertEq(address(wallet).balance, 1 ether - amount);
        assertEq(recipient.balance, amount);
    }

    function test_only_owner_can_transfer_ether() external {
        // initial balance is 1 ether
        vm.deal(address(wallet), 1 ether);

        // when the attacker sends some ether, then the transfer fails
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSignature("NotAuthorized()"));
        wallet.transferEth(recipient, 0.1 ether);
    }
}
