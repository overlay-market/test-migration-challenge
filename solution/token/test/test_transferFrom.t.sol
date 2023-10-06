// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {Token} from "../src/Token.sol";

contract TokenTest is Test {
    Token public token;
    address public account1;
    address public account2;
    address public account3;

    event Transfer(address indexed from, address indexed to, uint256 value);

    function setUp() public {
        token = new Token("Test Token", "TST", 18, 1e21);
        account1 = address(1);
        account2 = address(2);
        account3 = address(3);

        token.transfer(account1, 1000000);
    }

    function testSenderBalanceDecreases() public {
        uint256 senderBalance = token.balanceOf(account1);
        uint256 amount = senderBalance / 4;

        vm.prank(account1);
        token.approve(account2, amount);

        vm.prank(account2);
        token.transferFrom(account1, account3, amount);

        assertEq(token.balanceOf(account1), senderBalance - amount);
    }

    function testReceiverBalancesIncreases() public {
        uint256 receiverBalance = token.balanceOf(account3);
        uint256 amount = token.balanceOf(account1) / 4;

        vm.prank(account1);
        token.approve(account2, amount);
        vm.prank(account2);
        token.transferFrom(account1, account3, amount);

        assertEq(token.balanceOf(account3), receiverBalance + amount);
    }

    function testCallerBalanceNotAffected() public {
        uint256 callerBalance = token.balanceOf(account2);
        uint256 amount = token.balanceOf(account1);

        vm.prank(account1);
        token.approve(account2, amount);
        vm.prank(account2);
        token.transferFrom(account1, account3, amount);

        assertEq(token.balanceOf(account2), callerBalance);
    }

    function testCallerApprovalAffected() public {
        uint256 approvalAmount = token.balanceOf(account1);
        uint256 transferAmount = approvalAmount / 4;

        vm.prank(account1);
        token.approve(account2, approvalAmount);
        vm.prank(account2);
        token.transferFrom(account1, account3, transferAmount);

        assertEq(
            token.allowance(account1, account2),
            approvalAmount - transferAmount
        );
    }

    function testReceiverApprovalNotAffected() public {
        uint256 approvalAmount = token.balanceOf(account1);
        uint256 transferAmount = approvalAmount / 4;

        vm.startPrank(account1);
        token.approve(account2, approvalAmount);
        token.approve(account3, approvalAmount);
        vm.stopPrank();

        vm.prank(account2);
        token.transferFrom(account1, account3, transferAmount);

        assertEq(token.allowance(account1, account3), approvalAmount);
    }

    function testTotalSupplyNotAffected() public {
        uint256 totalSupply = token.totalSupply();
        uint256 amount = token.balanceOf(account1);

        vm.prank(account1);
        token.approve(account2, amount);

        vm.prank(account2);
        token.transferFrom(account1, account3, amount);

        assertEq(token.totalSupply(), totalSupply);
    }

    function testReturnsTrue() public {
        uint256 amount = token.balanceOf(account1);

        vm.prank(account1);
        token.approve(account2, amount);

        vm.prank(account2);
        bool success = token.transferFrom(account1, account3, amount);
        assertTrue(success);
    }

    function testTransferFullBalance() public {
        uint256 amount = token.balanceOf(account1);
        uint256 receiverBalance = token.balanceOf(account3);

        vm.prank(account1);
        token.approve(account2, amount);

        vm.prank(account2);
        token.transferFrom(account1, account3, amount);

        assertEq(token.balanceOf(account1), 0);
        assertEq(token.balanceOf(account3), receiverBalance + amount);
    }

    function testTransferZeroTokens() public {
        uint256 senderBalance = token.balanceOf(account1);
        uint256 receiverBalance = token.balanceOf(account3);

        vm.prank(account1);
        token.approve(account2, senderBalance);

        vm.prank(account2);
        token.transferFrom(account1, account3, 0);

        assertEq(token.balanceOf(account1), senderBalance);
        assertEq(token.balanceOf(account3), receiverBalance);
    }

    function testTransferZeroTokensWithoutApproval() public {
        uint256 senderBalance = token.balanceOf(account1);
        uint256 receiverBalance = token.balanceOf(account3);

        vm.prank(account2);
        token.transferFrom(account1, account3, 0);

        assertEq(token.balanceOf(account1), senderBalance);
        assertEq(token.balanceOf(account3), receiverBalance);
    }

    function testInsufficientBalance() public {
        uint256 balance = token.balanceOf(account1);

        vm.prank(account1);
        token.approve(account2, balance + 1);

        vm.prank(account2);
        vm.expectRevert(bytes("Insufficient balance"));
        token.transferFrom(account1, account3, balance + 1);
    }

    function testInsufficientApproval() public {
        uint256 balance = token.balanceOf(account1);

        vm.prank(account1);
        token.approve(account2, balance - 1);

        vm.prank(account2);
        vm.expectRevert(bytes("Insufficient allowance"));
        token.transferFrom(account1, account3, balance);
    }

    function testNoApproval() public {
        uint256 balance = token.balanceOf(account1);

        vm.prank(account2);
        vm.expectRevert(bytes("Insufficient allowance"));
        token.transferFrom(account1, account3, balance);
    }

    function testRevokedApproval() public {
        uint256 balance = token.balanceOf(account1);

        vm.startPrank(account1);
        token.approve(account2, balance);
        token.approve(account2, 0);
        vm.stopPrank();

        vm.prank(account2);
        vm.expectRevert(bytes("Insufficient allowance"));
        token.transferFrom(account1, account3, balance);
    }

    function testTransferToSelf() public {
        uint256 senderBalance = token.balanceOf(account1);
        uint256 amount = senderBalance / 4;

        vm.startPrank(account1);
        token.approve(account1, senderBalance);
        token.transferFrom(account1, account1, amount);
        vm.stopPrank();

        assertEq(token.balanceOf(account1), senderBalance);
        assertEq(token.allowance(account1, account1), senderBalance - amount);
    }

    function testTransferToSelfNoApproval() public {
        uint256 amount = token.balanceOf(account1);

        vm.prank(account1);
        vm.expectRevert(bytes("Insufficient allowance"));
        token.transferFrom(account1, account1, amount);
    }

    function testTransferEventFires() public {
        uint256 amount = token.balanceOf(account1);

        vm.prank(account1);
        token.approve(account2, amount);

        // which data to check
        vm.expectEmit(true, true, false, true);
        //emit the expected event
        emit Transfer(account1, account3, amount);

        vm.prank(account2);
        token.transferFrom(account1, account3, amount);
    }
}
