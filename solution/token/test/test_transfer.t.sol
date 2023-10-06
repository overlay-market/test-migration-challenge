// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {Token} from "../src/Token.sol";

contract TokenTest is Test {
    Token public token;
    address public account1;
    address public account2;

    event Transfer(address indexed from, address indexed to, uint256 value);

    function setUp() public {
        token = new Token("Test Token", "TST", 18, 1e21);
        account1 = address(1);
        account2 = address(2);

        token.transfer(account1, 1000000);
    }

    function testSenderBalanceDecreases() public {
        uint256 senderBalance = token.balanceOf(account1);
        uint256 amount = senderBalance / 4;

        vm.prank(account1);
        token.transfer(account2, amount);

        uint256 newSenderBalance = token.balanceOf(account1);

        assertEq(newSenderBalance, senderBalance - amount);
    }

    function testReceiverBalanceIncreases() public {
        uint256 receiverBalance = token.balanceOf(account2);
        uint256 amount = token.balanceOf(account1) / 4;

        vm.prank(account1);
        token.transfer(account2, amount);

        assertEq(token.balanceOf(account2), receiverBalance + amount);
    }

    function testTotalSupplyNotAffected() public {
        uint256 totalSupply = token.totalSupply();
        uint256 amount = token.balanceOf(account1);

        vm.prank(account1);
        token.transfer(account2, amount);

        assertEq(token.totalSupply(), totalSupply);
    }

    function testReturnsTrue() public {
        uint256 amount = token.balanceOf(account1);

        vm.prank(account1);
        bool success = token.approve(account2, amount);
        assertTrue(success);
    }

    function testTransferFullBalance() public {
        uint256 amount = token.balanceOf(account1);
        uint256 receiverBalance = token.balanceOf(account2);

        vm.prank(account1);
        token.transfer(account2, amount);

        assertEq(token.balanceOf(account1), 0);
        assertEq(token.balanceOf(account2), receiverBalance + amount);
    }

    function testTransferZeroTokens() public {
        uint256 senderBalance = token.balanceOf(account1);
        uint256 receiverBalance = token.balanceOf(account2);

        vm.prank(account1);
        token.transfer(account2, 0);

        assertEq(token.balanceOf(account1), senderBalance);
        assertEq(token.balanceOf(account2), receiverBalance);
    }

    function testTransferToSelf() public {
        uint256 senderBalance = token.balanceOf(account1);
        uint256 amount = senderBalance / 4;

        vm.prank(account1);
        token.transfer(account1, amount);

        assertEq(token.balanceOf(account1), senderBalance);
    }

    function testInsufficientBalance() public {
        uint256 balance = token.balanceOf(account1);

        vm.expectRevert(bytes("Insufficient balance"));
        vm.prank(account1);
        token.transfer(account2, balance + 1);
    }

    function testTransferEventFires() public {
        uint256 amount = token.balanceOf(account1);

        // which data to check
        vm.expectEmit(true, true, false, true);
        //emit the expected event
        emit Transfer(account1, account2, amount);

        vm.prank(account1);
        token.transfer(account2, amount);
    }
}
