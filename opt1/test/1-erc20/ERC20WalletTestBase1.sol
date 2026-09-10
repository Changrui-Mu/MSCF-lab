// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";

import {IERC20Wallet} from "src/1-erc20/interfaces/IERC20Wallet.sol";
import {BasicERC20} from "src/1-erc20/BasicERC20.sol";

// [quirk] This mock mimics the two famous non-standard behaviors of real USDT on mainnet.
// A naive ERC20Wallet passes the BasicERC20 tests but fails against this mock.
// Real DeFi protocols (0x v1, early Uniswap forks) hit production bugs from these exact quirks.
contract USDTMock {
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 value);

    mapping(address => mapping(address => uint256)) public allowance;
    mapping(address => uint256) public balanceOf;

    constructor(uint256 initialBalance) {
        balanceOf[msg.sender] = initialBalance;
    }

    /// @notice does not return anything on transfer
    // [quirk #1] No `returns (bool)` — the ERC-20 standard says transfer MUST return bool. USDT doesn't.
    //   Caller pain: `IERC20(usdt).transfer(...)` makes Solidity generate ABI-decode code expecting
    //   32 bytes back. USDT returns 0 bytes → the decoder reverts in the caller, even though the EVM
    //   call itself succeeded and the storage update landed. The transfer didn't fail; *decoding* did.
    //   Fix in the wallet: use low-level `.call` and only decode the bool when returndata.length > 0,
    //                      or just use OpenZeppelin's `SafeERC20.safeTransfer` which does exactly that.
    function transfer(address to, uint256 amount) public {
        require(amount <= balanceOf[msg.sender], "USDTMock: transfer failed");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;

        emit Transfer(msg.sender, to, amount);
    }

    /// prevents the famous approval race condition by requiring the allowance
    /// to be reset to 0 before approving another amount
    function approve(address spender, uint256 amount) public returns (bool) {
        // To change the approve amount you first have to reduce the addresses`
        //  allowance to zero by calling `approve(_spender, 0)` if it is not
        //  already 0 to mitigate the race condition described here:
        //  https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729

        // [quirk #2] Approve-from-nonzero-to-nonzero is forbidden.
        //   The race: spender sees a pending tx lowering allowance N → M, front-runs to spend N first,
        //   then spends M after the tx lands → net spent = N + M instead of just M.
        //   USDT blocks this by requiring allowance == 0 before any new non-zero approval.
        //   Caller pain: a single `approve(spender, newAmount)` reverts if previous allowance is non-zero.
        //   Fix in the wallet: always `approve(spender, 0)` then `approve(spender, newAmount)`,
        //                      or use OZ's `SafeERC20.forceApprove` which encapsulates this.
        require(!((amount != 0) && (allowance[msg.sender][spender] != 0)));

        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }
}

abstract contract ERC20WalletTestBase1 is Test {
    IERC20Wallet public wallet;
    BasicERC20 public token;
    USDTMock public usdtMock;

    address public owner;
    address public donator;
    address public attacker;
    address payable public recipient;

    function setUp() public virtual {
        owner = makeAddr("owner");
        donator = makeAddr("donator");
        attacker = makeAddr("attacker");
        recipient = payable(makeAddr("recipient"));

        uint256 initialBalance = 100 * 10 ** 18;

        token = new BasicERC20();
        token.mint(owner, initialBalance);
        token.mint(donator, initialBalance);

        usdtMock = new USDTMock(100 * 10 ** 6);
    }

    // Checkpoint 0 functionality carries over — but this time you WROTE it
    // (constructor, receive, transferEth), so we test it again here.
    function test_can_receive_and_send_eth() public {
        // plain ETH send with empty calldata — requires the special function you declared
        vm.deal(donator, 1 ether);
        vm.prank(donator);
        (bool ok,) = address(wallet).call{value: 1 ether}("");
        assertTrue(ok, "wallet rejected a plain ETH send");
        assertEq(address(wallet).balance, 1 ether);

        // owner sends ETH out
        vm.prank(owner);
        wallet.transferEth(recipient, 0.4 ether);
        assertEq(recipient.balance, 0.4 ether);
        assertEq(address(wallet).balance, 0.6 ether);
    }

    function test_only_owner_can_transfer_eth() public {
        vm.deal(address(wallet), 1 ether);

        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSignature("NotAuthorized()"));
        wallet.transferEth(recipient, 1 ether);
    }

    function test_can_receive_and_send_erc20_token() public {
        vm.prank(donator);
        uint256 amount_in = 10 * 10 ** 18;
        token.transfer(address(wallet), amount_in); // seeding the wallet — required by the test below

        // when the owner transfers the token
        vm.prank(owner);
        uint256 amount_out = 5 * 10 ** 18;
        wallet.transferERC20(address(token), recipient, amount_out);

        // then the transfer succeeds and the recipient is credited
        assertEq(token.balanceOf(recipient), amount_out);
        assertEq(token.balanceOf(address(wallet)), amount_in - amount_out);
    }

    function test_only_owner_can_transfer_erc20_token() public {
        vm.prank(donator);
        uint256 amount_in = 10 * 10 ** 18;
        token.transfer(address(wallet), amount_in);

        // when the attacker tries to transfer the token, then it reverts with NotAuthorized
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSignature("NotAuthorized()"));
        wallet.transferERC20(address(token), recipient, 10 * 10 ** 18);
    }

    function test_can_approve_erc20_token() public {
        // when the owner approves the token
        vm.prank(owner);
        uint256 approve_amount = 42 * 10 ** 18;
        wallet.approveERC20(address(token), recipient, approve_amount);

        // then the approval succeeds and the allowance is reflected
        assertEq(token.allowance(address(wallet), recipient), approve_amount);
    }

    function test_only_owner_can_approve_erc20_token() public {
        // when the attacker tries to approve the token, then it reverts with NotAuthorized
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSignature("NotAuthorized()"));
        wallet.approveERC20(address(token), attacker, 0);
    }

    // [quirk test #1] Exercises USDTMock's no-return-bool transfer (see quirk #1 in USDTMock above).
    // A wallet that calls `IERC20(token).transfer(...)` will revert here on ABI decode, even though
    // the storage update would have succeeded. Passing this test forces you to use SafeERC20.safeTransfer
    // or hand-rolled low-level `.call` with conditional return-data decoding.
    function test_handles_usdt_like_token_transfers() public {
        // seed the wallet with 100 USDT
        usdtMock.transfer(address(wallet), 100 * 10 ** 6);

        // when the owner transfers the token
        vm.prank(owner);
        uint256 amount = 42 * 10 ** 6;
        wallet.transferERC20(address(usdtMock), recipient, amount);

        // then the transfer succeeds and the recipient is credited
        assertEq(usdtMock.balanceOf(recipient), amount);
    }

    // [quirk test #2] Exercises USDTMock's nonzero→nonzero approve guard (see quirk #2 in USDTMock above).
    // Note this is a Foundry *fuzz* test — the two arguments are randomized across many runs. Once
    // the fuzzer picks (amount1 != 0, amount2 != 0), a naive second `approve(spender, amount2)` reverts.
    // Passing this test forces you to reset allowance to 0 before any new approval — i.e.
    // use SafeERC20.forceApprove or do the two-call dance manually.
    function test_handles_usdt_like_token_approvals(uint256 amount1, uint256 amount2) public {
        // when the owner approves the token
        vm.prank(owner);
        wallet.approveERC20(address(usdtMock), recipient, amount1);

        // then the approval succeeds and the allowance is reflected
        assertEq(usdtMock.allowance(address(wallet), recipient), amount1);

        // when the owner approves a different amount
        vm.prank(owner);
        wallet.approveERC20(address(usdtMock), recipient, amount2);

        // then the approval succeeds and the allowance is reflected
        assertEq(usdtMock.allowance(address(wallet), recipient), amount2);
    }
}
