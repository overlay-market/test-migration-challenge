// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "forge-std/Test.sol";
import "forge-std/console.sol";
import {Token} from "../src/Token.sol";

contract TokenTest is Test {
    Token public token;
    address public account1;
    address public account2;

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    function setUp() public {
        token = new Token("Test Token", "TST", 18, 1e21);
        account1 = address(1);
        account2 = address(2);
    }

    function testInitialApprovalIsZero() public {
        assertEq(token.allowance(msg.sender, account1), 0);
    }

    function testApprove() public {
        vm.prank(account1);
        token.approve(account2, 10 ** 19);

        assertEq(token.allowance(account1, account2), 10 ** 19);
    }

    function testModifyApprove() public {
        vm.startPrank(account1);
        token.approve(account2, 10 ** 19);
        assertEq(token.allowance(account1, account2), 10 ** 19);

        token.approve(account2, 12345);
        assertEq(token.allowance(account1, account2), 12345);
        vm.stopPrank();
    }

    function testRevokeApprove() public {
        vm.startPrank(account1);
        token.approve(account2, 10 ** 19);
        assertEq(token.allowance(account1, account2), 10 ** 19);

        token.approve(account2, 0);
        assertEq(token.allowance(account1, account2), 0);
        vm.stopPrank();
    }

    /// forge-config: default.fuzz.runs = 1000
    function testFuzzRevokeApprove(uint256 _value) public {
        vm.startPrank(account1);
        vm.assume(_value > 0);
        token.approve(account2, _value);

        token.approve(account2, 0);

        assertEq(token.allowance(account1, account2), 0);
    }

    function testApproveSelf() public {
        vm.prank(account1);
        token.approve(account1, 10 ** 19);
        assertEq(token.allowance(account1, account1), 10 ** 19);
    }

    function testOnlyAffectsTarget() public {
        vm.prank(account1);
        token.approve(account2, 10 ** 19);
        assertEq(token.allowance(account1, account2), 10 ** 19);
        assertEq(token.allowance(account2, account1), 0);
    }

    function testReturnsTrue() public {
        vm.prank(account1);
        bool success = token.approve(account2, 10 ** 19);
        assertTrue(success);
    }

    function testApprovalEventFires() public {
        // which data to check
        vm.expectEmit(true, true, false, true);
        //emit the expected event
        emit Approval(account1, account2, 10 ** 19);

        vm.prank(account1);
        token.approve(account2, 10 ** 19);
    }
}
