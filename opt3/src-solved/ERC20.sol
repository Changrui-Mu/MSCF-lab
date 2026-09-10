// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract ERC20 {
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(uint256 initialSupply, string memory tokenName, string memory tokenSymbol) {
        totalSupply = initialSupply * 10 ** uint256(decimals);
        balanceOf[msg.sender] = totalSupply;
        name = tokenName;
        symbol = tokenSymbol;
    }

    function _transfer(address from, address to, uint256 value) internal {
        require(to != address(0));
        require(balanceOf[from] >= value);
        require(balanceOf[to] + value >= balanceOf[to]);

        uint256 previousBalances = balanceOf[from] + balanceOf[to];
        balanceOf[from] -= value;
        balanceOf[to] += value;
        emit Transfer(from, to, value);
        assert(balanceOf[from] + balanceOf[to] == previousBalances);
    }

    function transfer(address to, uint256 value) public returns (bool success) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) public returns (bool success) {
        require(value <= allowance[from][msg.sender], "Invalid allowance");
        allowance[from][msg.sender] -= value;
        _transfer(from, to, value);
        return true;
    }

    function approve(address spender, uint256 value) public returns (bool success) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }
}
