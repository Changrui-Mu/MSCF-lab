// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {WalletTestBase0} from "./WalletTestBase0.sol";
import {BasicWallet} from "src/0-basic/BasicWallet.sol";

contract WalletTestCheckpoint0 is WalletTestBase0 {
    function setUp() public override {
        super.setUp();

        vm.startPrank(owner);
        wallet = new BasicWallet();
        vm.stopPrank();
    }
}
