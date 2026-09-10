// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";

import "src/2-multisig/interfaces/IMultisigWallet.sol";

abstract contract WalletTestBase2 is Test {
    IMultisigWallet public wallet;

    address public admin1;
    address public admin2;
    address public admin3;
    address public donator;
    address payable public recipient;
    address public attacker;

    bytes transferEthAction;

    function setUp() public virtual {
        admin1 = makeAddr("admin1");
        admin2 = makeAddr("admin2");
        admin3 = makeAddr("admin3");
        donator = makeAddr("donator");
        recipient = payable(makeAddr("recipient"));
        attacker = makeAddr("attacker");

        // Prepare an action to send one ETH to recipient
        transferEthAction = abi.encodeWithSelector(wallet.transferEth.selector, recipient, 1 ether);
    }

    function deployWallet(address[] memory admins) public virtual returns (IMultisigWallet);

    function test_admins_are_set() external {
        assertEq(wallet.admins(0), admin1);
        assertEq(wallet.admins(1), admin2);
        assertEq(wallet.admins(2), admin3);

        vm.expectRevert();
        wallet.admins(3);
    }

    function test_rejects_too_few_admins() external {
        address[] memory admins = new address[](2);
        admins[0] = admin1;
        admins[1] = admin2;
        vm.expectRevert(abi.encodeWithSignature("BadConfig()"));
        deployWallet(admins);
    }

    function test_rejects_too_many_admins() external {
        address[] memory admins = new address[](4);
        admins[0] = admin1;
        admins[1] = admin2;
        admins[2] = admin3;
        admins[3] = address(0);
        vm.expectRevert(abi.encodeWithSignature("BadConfig()"));
        deployWallet(admins);
    }

    function test_requires_unique_admins() external {
        address[] memory admins = new address[](3);
        admins[0] = admin1;
        admins[1] = admin2;
        admins[2] = admin1;
        vm.expectRevert(abi.encodeWithSignature("BadConfig()"));
        deployWallet(admins);
    }

    function test_approve_emits_approved_event() external {
        vm.expectEmit(true, true, true, true);
        emit Approved(admin1, transferEthAction);

        vm.prank(admin1);
        wallet.approve(transferEthAction);
    }

    function test_approve_and_execute_happy_path() external {
        vm.deal(address(wallet), 100 ether);

        vm.prank(admin1);
        wallet.approve(transferEthAction);

        vm.prank(admin2);
        wallet.approve(transferEthAction);

        // note: anyone can execute the action if it is approved by 2 or more admins
        vm.prank(attacker);
        vm.expectEmit(true, true, true, true);
        emit Executed(attacker, transferEthAction);

        wallet.execute(transferEthAction);
        assertEq(recipient.balance, 1 ether);
    }

    function test_can_not_execute_without_approval() external {
        vm.prank(admin1);
        vm.expectRevert(abi.encodeWithSignature("NotAuthorized()"));
        wallet.execute(transferEthAction);
    }

    function test_can_not_execute_with_single_approval() external {
        vm.prank(admin1);
        wallet.approve(transferEthAction);

        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSignature("NotAuthorized()"));
        wallet.execute(transferEthAction);
    }

    function test_execute_by_admin_counts_as_approval() external {
        vm.deal(address(wallet), 100 ether);

        vm.prank(admin1);
        wallet.approve(transferEthAction);

        vm.prank(admin2);
        wallet.execute(transferEthAction);

        assertEq(recipient.balance, 1 ether);
    }

    function test_can_not_execute_twice() external {
        vm.deal(address(wallet), 100 ether);

        vm.prank(admin1);
        wallet.approve(transferEthAction);

        vm.prank(admin2);
        wallet.approve(transferEthAction);

        vm.prank(admin3);
        wallet.execute(transferEthAction);

        vm.prank(admin3);
        vm.expectRevert(abi.encodeWithSignature("NotAuthorized()"));
        wallet.execute(transferEthAction);
    }

    function test_admin_can_not_call_transfer_eth_directly() external {
        vm.prank(admin1);
        vm.expectRevert(abi.encodeWithSignature("NotAuthorized()"));
        wallet.transferEth(recipient, 1 ether);
    }

    function test_same_admin_can_not_approve_twice() external {
        vm.prank(admin1);
        wallet.approve(transferEthAction);

        vm.prank(admin1);
        vm.expectRevert(abi.encodeWithSignature("AlreadyApproved()"));
        wallet.approve(transferEthAction);
    }
}
