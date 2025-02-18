// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import "../src/CollateralPool01.sol";
import "./Helper.sol";

contract CollateralPool01Test is Test, Helper {
    CollateralPool01 public collateralPool;
    address public constant owner = 0xFD1066acf2FC47F3b2DaCec43E76321644dC9928;
    address public constant addr1 = 0x373FB35c5068f49deF8C2A74C0Fb3a82df02C667;
    uint public constant WITHDRAW_PERIOD = 1 days;

    function setUp() public {
        setupAll();
        collateralPool = new CollateralPool01(owner, WITHDRAW_PERIOD);
    }

    // Tests basic deposit functionality
    function testCollateralPool01_deposit() public {
        uint depositAmount = 100 * 10**18;
        
        vm.startPrank(WETH_WHALE);
        WETH_ERC20.approve(address(collateralPool), depositAmount);
        
        vm.expectEmit(true, true, true, true, address(collateralPool));
        emit ICollateralPool01.Deposited(WETH_WHALE, WETH_ERC20, depositAmount);
        
        collateralPool.deposit(WETH_ERC20, depositAmount);
        vm.stopPrank();

        assertEq(
            collateralPool.tokenBalance(WETH_WHALE, WETH_ERC20),
            depositAmount,
            "Depositor balance should match deposit amount"
        );
        assertEq(
            WETH_ERC20.balanceOf(address(collateralPool)),
            depositAmount,
            "Pool should hold deposited tokens"
        );
    }

    // Tests multiple deposits from same user
    function testCollateralPool01_deposit_multiple() public {
        uint firstDeposit = 50 * 10**18;
        uint secondDeposit = 75 * 10**18;
        
        vm.startPrank(WETH_WHALE);
        WETH_ERC20.approve(address(collateralPool), firstDeposit + secondDeposit);
        
        collateralPool.deposit(WETH_ERC20, firstDeposit);
        collateralPool.deposit(WETH_ERC20, secondDeposit);
        vm.stopPrank();

        assertEq(
            collateralPool.tokenBalance(WETH_WHALE, WETH_ERC20),
            firstDeposit + secondDeposit,
            "Depositor balance should accumulate multiple deposits"
        );
    }

    // Tests deposits from multiple users
    function testCollateralPool01_deposit_multipleUsers() public {
        uint user1Deposit = 100 * 10**18;
        uint user2Deposit = 150 * 10**18;
        
        // First user deposit
        vm.startPrank(WETH_WHALE);
        WETH_ERC20.approve(address(collateralPool), user1Deposit);
        collateralPool.deposit(WETH_ERC20, user1Deposit);
        vm.stopPrank();

        // Transfer some WETH to second user
        vm.prank(WETH_WHALE);
        WETH_ERC20.transfer(addr1, user2Deposit);

        // Second user deposit
        vm.startPrank(addr1);
        WETH_ERC20.approve(address(collateralPool), user2Deposit);
        collateralPool.deposit(WETH_ERC20, user2Deposit);
        vm.stopPrank();

        assertEq(
            collateralPool.tokenBalance(WETH_WHALE, WETH_ERC20),
            user1Deposit,
            "First user balance should match their deposit"
        );
        assertEq(
            collateralPool.tokenBalance(addr1, WETH_ERC20),
            user2Deposit,
            "Second user balance should match their deposit"
        );
        assertEq(
            WETH_ERC20.balanceOf(address(collateralPool)),
            user1Deposit + user2Deposit,
            "Pool should hold total deposits"
        );
    }

    // Tests deposit of multiple token types
    function testCollateralPool01_deposit_multipleTokens() public {
        uint wethAmount = 100 * 10**18;
        uint usdcAmount = 1000 * 10**6;
        
        vm.startPrank(WETH_WHALE);
        WETH_ERC20.approve(address(collateralPool), wethAmount);
        collateralPool.deposit(WETH_ERC20, wethAmount);
        vm.stopPrank();

        vm.startPrank(USDC_WHALE);
        USDC_ERC20.approve(address(collateralPool), usdcAmount);
        collateralPool.deposit(USDC_ERC20, usdcAmount);
        vm.stopPrank();

        assertEq(
            collateralPool.tokenBalance(WETH_WHALE, WETH_ERC20),
            wethAmount,
            "WETH balance should match deposit"
        );
        assertEq(
            collateralPool.tokenBalance(USDC_WHALE, USDC_ERC20),
            usdcAmount,
            "USDC balance should match deposit"
        );
    }

    // Tests deposit with zero amount
    function testCollateralPool01_deposit_zeroAmount() public {
        vm.startPrank(WETH_WHALE);
        WETH_ERC20.approve(address(collateralPool), 1);
        collateralPool.deposit(WETH_ERC20, 0);
        vm.stopPrank();

        assertEq(
            collateralPool.tokenBalance(WETH_WHALE, WETH_ERC20),
            0,
            "Zero deposit should result in zero balance"
        );
    }

    // Tests deposit fails without approval
    function testCollateralPool01_deposit_noApproval() public {
        uint depositAmount = 100 * 10**18;
        
        vm.startPrank(WETH_WHALE);
        vm.expectRevert();
        collateralPool.deposit(WETH_ERC20, depositAmount);
        vm.stopPrank();
    }

    // Tests deposit fails with insufficient balance
    function testCollateralPool01_deposit_insufficientBalance() public {
        uint whaleBalance = WETH_ERC20.balanceOf(WETH_WHALE);
        uint depositAmount = whaleBalance + 1;
        
        vm.startPrank(WETH_WHALE);
        WETH_ERC20.approve(address(collateralPool), depositAmount);
        vm.expectRevert();
        collateralPool.deposit(WETH_ERC20, depositAmount);
        vm.stopPrank();
    }
} 