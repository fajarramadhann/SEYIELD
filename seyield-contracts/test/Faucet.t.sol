// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Faucet} from "../src/Faucet.sol";
import {MockUSDC} from "../src/MockUSDC.sol";

contract FaucetTest is Test {
    Faucet public faucet;
    MockUSDC public usdc;
    address public constant OWNER = address(0x1);
    address public constant USER = address(0x2);

    function setUp() public {
        vm.startPrank(OWNER);
        usdc = new MockUSDC();
        faucet = new Faucet(address(usdc));

        // Fund faucet
        usdc.transfer(address(faucet), 10000e6);
        vm.deal(address(faucet), 100 ether);
        vm.stopPrank();
    }

    function testClaimTokens() public {
        // Make sure USER has ETH to receive
        vm.deal(USER, 0);

        vm.prank(USER);
        faucet.claimTokens();

        assertEq(usdc.balanceOf(USER), 1000e6);
        assertEq(USER.balance, 1 ether);
    }

    function test_RevertWhen_ClaimTooSoon() public {
        // Make sure USER has ETH to receive
        vm.deal(USER, 0);

        vm.prank(USER);
        faucet.claimTokens();

        vm.prank(USER);
        vm.expectRevert("Wait 24h between claims");
        faucet.claimTokens(); // Should revert
    }

    function testClaimAfterInterval() public {
        // Make sure USER has ETH to receive
        vm.deal(USER, 0);

        vm.prank(USER);
        faucet.claimTokens();

        // Advance time beyond claim interval
        vm.warp(block.timestamp + 24 hours + 1);

        vm.prank(USER);
        faucet.claimTokens(); // Should succeed

        assertEq(usdc.balanceOf(USER), 2000e6);
        assertEq(USER.balance, 2 ether);
    }

    function testOwnerDeposit() public {
        vm.startPrank(OWNER);
        usdc.approve(address(faucet), 5000e6);

        // Make sure OWNER has enough ETH
        vm.deal(OWNER, 10 ether);

        faucet.depositTokens{value: 5 ether}(5000e6);
        vm.stopPrank();

        assertEq(usdc.balanceOf(address(faucet)), 15000e6);
        assertEq(address(faucet).balance, 105 ether);
    }
}