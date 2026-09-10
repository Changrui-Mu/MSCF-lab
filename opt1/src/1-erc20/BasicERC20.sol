// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract BasicERC20 is ERC20 {
    constructor() ERC20("BasicERC20", "BET") {}

    /// @notice Mint any number of tokens to any address who wants them
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
