// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ERC20WalletTestBase1} from "./ERC20WalletTestBase1.sol";
import {ERC20Wallet} from "src/1-erc20/ERC20Wallet.sol";

contract ERC20WalletTestCheckpoint1 is ERC20WalletTestBase1 {
    function setUp() public override {
        super.setUp();

        vm.startPrank(owner);
        wallet = new ERC20Wallet();
        vm.stopPrank();
    }
}
