// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {WalletTestBase2} from "./WalletTestBase2.sol";
import "src/2-multisig/interfaces/IMultisigWallet.sol";
import {MultisigWallet} from "src/2-multisig/MultisigWallet.sol";

contract WalletTestCheckpoint2 is WalletTestBase2 {
    function setUp() public override {
        super.setUp();

        address[] memory admins = new address[](3);
        admins[0] = admin1;
        admins[1] = admin2;
        admins[2] = admin3;
        wallet = new MultisigWallet(admins);
    }

    function deployWallet(address[] memory admins) public override returns (IMultisigWallet) {
        return new MultisigWallet(admins);
    }
}
