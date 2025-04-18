// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {CollateralPool01} from "../src/CollateralPool01.sol";
import {ICollateralPool01} from "../src/interfaces/ICollateralPool01.sol";
import "./Helper.sol";

contract CollateralPool01Test is Test, Helper {
    CollateralPool01 public collateralPool;
    address public constant owner = 0xFD1066acf2FC47F3b2DaCec43E76321644dC9928;
    address public constant addr1 = 0x373FB35c5068f49deF8C2A74C0Fb3a82df02C667;
    address public constant addr2 = 0x5Df7C65332BB095B7b108336A4f4eC7E98D66a61;
    uint public constant WITHDRAW_PERIOD = 1 days;

    function setUp() public {
        setupAll();

        // test emit WithdrawPeriodUpdated event
        address computedCollateralPoolAddr = vm.computeCreateAddress(owner, 0);
        vm.expectEmit(true, false, false, true, computedCollateralPoolAddr);
        emit ICollateralPool01.WithdrawPeriodUpdated(WITHDRAW_PERIOD);

        // deploy CollateralPool01
        vm.prank(owner);
        collateralPool = new CollateralPool01(owner, WITHDRAW_PERIOD);
        assertEq(collateralPool.withdrawPeriod(), WITHDRAW_PERIOD, "Withdraw period should be correctly set");

        // Transfer WETH to test addresses
        vm.startPrank(WETH_WHALE);
        WETH_ERC20.transfer(addr1, 1000 * 10**18);
        WETH_ERC20.transfer(addr2, 1000 * 10**18);
        vm.stopPrank();

        // Transfer USDC to test addresses
        vm.startPrank(USDC_WHALE);
        USDC_ERC20.transfer(addr1, 1_000_000 * 10**6);
        USDC_ERC20.transfer(addr2, 1_000_000 * 10**6);
        vm.stopPrank();
    }

    // Tests basic deposit functionality
    function testCollateralPool01_deposit() public {
        uint depositAmount = 100 * 10**18;
        
        vm.startPrank(addr1);
        WETH_ERC20.approve(address(collateralPool), depositAmount);
        
        vm.expectEmit(true, false, false, true, address(collateralPool));
        emit ICollateralPool01.Deposited(addr1, WETH_ERC20, depositAmount);
        
        collateralPool.deposit(WETH_ERC20, depositAmount);
        vm.stopPrank();

        assertEq(
            collateralPool.tokenBalance(addr1, WETH_ERC20),
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
        
        vm.startPrank(addr1);
        WETH_ERC20.approve(address(collateralPool), firstDeposit + secondDeposit);
        
        collateralPool.deposit(WETH_ERC20, firstDeposit);
        collateralPool.deposit(WETH_ERC20, secondDeposit);
        vm.stopPrank();

        assertEq(
            collateralPool.tokenBalance(addr1, WETH_ERC20),
            firstDeposit + secondDeposit,
            "Depositor balance should accumulate multiple deposits"
        );
    }

    // Tests deposits from multiple users
    function testCollateralPool01_deposit_multipleUsers() public {
        uint user1Deposit = 100 * 10**18;
        uint user2Deposit = 150 * 10**18;
        
        // First user deposit
        vm.startPrank(addr1);
        WETH_ERC20.approve(address(collateralPool), user1Deposit);
        collateralPool.deposit(WETH_ERC20, user1Deposit);
        vm.stopPrank();

        // Second user deposit
        vm.startPrank(addr2);
        WETH_ERC20.approve(address(collateralPool), user2Deposit);
        collateralPool.deposit(WETH_ERC20, user2Deposit);
        vm.stopPrank();

        assertEq(
            collateralPool.tokenBalance(addr1, WETH_ERC20),
            user1Deposit,
            "First user balance should match their deposit"
        );
        assertEq(
            collateralPool.tokenBalance(addr2, WETH_ERC20),
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
        
        vm.startPrank(addr1);
        WETH_ERC20.approve(address(collateralPool), wethAmount);
        collateralPool.deposit(WETH_ERC20, wethAmount);
        vm.stopPrank();

        vm.startPrank(addr2);
        USDC_ERC20.approve(address(collateralPool), usdcAmount);
        collateralPool.deposit(USDC_ERC20, usdcAmount);
        vm.stopPrank();

        assertEq(
            collateralPool.tokenBalance(addr1, WETH_ERC20),
            wethAmount,
            "WETH balance should match deposit"
        );
        assertEq(
            collateralPool.tokenBalance(addr2, USDC_ERC20),
            usdcAmount,
            "USDC balance should match deposit"
        );
    }

    // Tests deposit with zero amount
    function testCollateralPool01_deposit_zeroAmount() public {
        vm.startPrank(addr1);
        WETH_ERC20.approve(address(collateralPool), 1);
        collateralPool.deposit(WETH_ERC20, 0);
        vm.stopPrank();

        assertEq(
            collateralPool.tokenBalance(addr1, WETH_ERC20),
            0,
            "Zero deposit should result in zero balance"
        );
    }

    // Tests deposit fails with insufficient balance
    function testCollateralPool01_deposit_insufficientBalance() public {
        uint balance = WETH_ERC20.balanceOf(addr1);
        uint depositAmount = balance + 1;
        
        vm.startPrank(addr1);
        WETH_ERC20.approve(address(collateralPool), depositAmount);
        vm.expectRevert();
        collateralPool.deposit(WETH_ERC20, depositAmount);
        vm.stopPrank();
    }

    // Tests startWithdraw fails with insufficient balance
    function testCollateralPool01_startWithdraw_insufficientBalance() public {
        uint depositAmount = 100 * 10**18;
        uint withdrawAmount = depositAmount + 1;

        vm.startPrank(addr1);
        WETH_ERC20.approve(address(collateralPool), depositAmount);
        collateralPool.deposit(WETH_ERC20, depositAmount);
        
        vm.expectRevert(abi.encodeWithSelector(ICollateralPool01.InsufficientBalance.selector, depositAmount));
        collateralPool.startWithdraw(WETH_ERC20, withdrawAmount);
        vm.stopPrank();
    }

    // Tests startWithdraw state changes
    function testCollateralPool01_startWithdraw_state() public {
        uint depositAmount = 100 * 10**18;
        uint withdrawAmount = 50 * 10**18;

        // Setup: deposit tokens
        vm.startPrank(addr1);
        WETH_ERC20.approve(address(collateralPool), depositAmount);
        collateralPool.deposit(WETH_ERC20, depositAmount);

        // Start withdraw
        collateralPool.startWithdraw(WETH_ERC20, withdrawAmount);
        vm.stopPrank();

        // Check token balance is reduced
        assertEq(
            collateralPool.tokenBalance(addr1, WETH_ERC20),
            depositAmount - withdrawAmount,
            "Token balance should be reduced by withdraw amount"
        );

        // Check nonce is incremented
        assertEq(
            collateralPool.withdrawNonce(addr1),
            1,
            "Withdraw nonce should be incremented"
        );

        // Check tokenWithdraws state
        (IERC20 token, uint startTime, uint amount) = collateralPool.tokenWithdraws(addr1, 1);
        assertEq(address(token), address(WETH_ERC20), "Token address should match");
        assertEq(startTime, block.timestamp, "Start time should be current block timestamp");
        assertEq(amount, withdrawAmount, "Withdraw amount should match");
    }

    // Tests startWithdraw event emission
    function testCollateralPool01_startWithdraw_event() public {
        uint depositAmount = 100 * 10**18;
        uint withdrawAmount = 50 * 10**18;

        // Setup: deposit tokens
        vm.startPrank(addr1);
        WETH_ERC20.approve(address(collateralPool), depositAmount);
        collateralPool.deposit(WETH_ERC20, depositAmount);

        // Expect WithdrawRequested event
        vm.expectEmit(true, false, false, true, address(collateralPool));
        emit ICollateralPool01.WithdrawRequested(addr1, 1, block.timestamp, WETH_ERC20, withdrawAmount);

        // Start withdraw
        collateralPool.startWithdraw(WETH_ERC20, withdrawAmount);
        vm.stopPrank();
    }

    // Tests startWithdraw with 0 amount
    function testCollateralPool01_startWithdraw_zeroAmount() public {
        uint depositAmount = 100 * 10**18;

        // Setup: deposit tokens
        vm.startPrank(addr1);
        WETH_ERC20.approve(address(collateralPool), depositAmount);
        collateralPool.deposit(WETH_ERC20, depositAmount);

        // Expect WithdrawAmountZero error
        vm.expectRevert(abi.encodeWithSelector(ICollateralPool01.WithdrawAmountZero.selector));
        collateralPool.startWithdraw(WETH_ERC20, 0);
        vm.stopPrank();
    }

    // Tests withdraw fails when nothing to withdraw
    function testCollateralPool01_withdraw_nothingToWithdraw() public {
        vm.startPrank(addr1);
        vm.expectRevert(ICollateralPool01.NothingToWithdraw.selector);
        collateralPool.withdraw(1);
        vm.stopPrank();
    }

    // Tests withdraw fails when withdraw period hasn't elapsed
    function testCollateralPool01_withdraw_notReady() public {
        uint depositAmount = 100 * 10**18;
        uint withdrawAmount = 50 * 10**18;

        // Setup: deposit and start withdraw
        vm.startPrank(addr1);
        WETH_ERC20.approve(address(collateralPool), depositAmount);
        collateralPool.deposit(WETH_ERC20, depositAmount);
        collateralPool.startWithdraw(WETH_ERC20, withdrawAmount);

        uint withdrawReadyTime = block.timestamp + WITHDRAW_PERIOD;
        vm.expectRevert(abi.encodeWithSelector(ICollateralPool01.WithdrawNotReady.selector, withdrawReadyTime));
        collateralPool.withdraw(1);
        vm.stopPrank();
    }

    // Tests successful withdraw
    function testCollateralPool01_withdraw_success() public {
        uint depositAmount = 100 * 10**18;
        uint withdrawAmount = 50 * 10**18;

        // Setup: deposit and start withdraw
        vm.startPrank(addr1);
        WETH_ERC20.approve(address(collateralPool), depositAmount);
        collateralPool.deposit(WETH_ERC20, depositAmount);
        collateralPool.startWithdraw(WETH_ERC20, withdrawAmount);

        // Advance time past withdraw period
        vm.warp(block.timestamp + WITHDRAW_PERIOD + 1);

        uint balanceBefore = WETH_ERC20.balanceOf(addr1);
        
        // Perform withdraw
        collateralPool.withdraw(1);
        vm.stopPrank();

        // Verify token transfer
        assertEq(
            WETH_ERC20.balanceOf(addr1),
            balanceBefore + withdrawAmount,
            "Tokens should be transferred to withdrawer"
        );

        // Verify withdraw request is deleted
        (IERC20 token, uint startTime, uint amount) = collateralPool.tokenWithdraws(addr1, 1);
        assertEq(amount, 0, "Withdraw request should be deleted");
        assertEq(address(token), address(0), "Token should be zero address");
        assertEq(startTime, 0, "Start time should be zero");
    }

    // Tests withdraw event emission
    function testCollateralPool01_withdraw_event() public {
        uint depositAmount = 100 * 10**18;
        uint withdrawAmount = 50 * 10**18;

        // Setup: deposit and start withdraw
        vm.startPrank(addr1);
        WETH_ERC20.approve(address(collateralPool), depositAmount);
        collateralPool.deposit(WETH_ERC20, depositAmount);
        collateralPool.startWithdraw(WETH_ERC20, withdrawAmount);

        // Advance time past withdraw period
        vm.warp(block.timestamp + WITHDRAW_PERIOD + 1);

        // Expect WithdrawCompleted event
        vm.expectEmit(true, false, false, true, address(collateralPool));
        emit ICollateralPool01.WithdrawCompleted(addr1, 1, WETH_ERC20, withdrawAmount);

        // Perform withdraw
        collateralPool.withdraw(1);
        vm.stopPrank();
    }

    // Tests multiple withdraws at different times
    function testCollateralPool01_withdraw_multiple() public {
        uint depositAmount = 100 * 10**18;
        uint firstWithdrawAmount = 30 * 10**18;
        uint secondWithdrawAmount = 40 * 10**18;

        // Setup: deposit tokens
        vm.startPrank(addr1);
        WETH_ERC20.approve(address(collateralPool), depositAmount);
        collateralPool.deposit(WETH_ERC20, depositAmount);

        // Start first withdraw
        collateralPool.startWithdraw(WETH_ERC20, firstWithdrawAmount);
        
        // Move forward 12 hours and start second withdraw
        vm.warp(block.timestamp + 12 hours);
        collateralPool.startWithdraw(WETH_ERC20, secondWithdrawAmount);

        // Verify both withdraws are stored correctly
        (IERC20 token1, uint startTime1, uint amount1) = collateralPool.tokenWithdraws(addr1, 1);
        (IERC20 token2, uint startTime2, uint amount2) = collateralPool.tokenWithdraws(addr1, 2);
        
        assertEq(amount1, firstWithdrawAmount, "First withdraw amount should be correct");
        assertEq(amount2, secondWithdrawAmount, "Second withdraw amount should be correct");
        assertEq(startTime2 - startTime1, 12 hours, "Withdraw times should be 12 hours apart");

        // Move forward past withdraw period for both withdraws
        vm.warp(block.timestamp + WITHDRAW_PERIOD);

        uint balanceBefore = WETH_ERC20.balanceOf(addr1);

        // Withdraw both
        collateralPool.withdraw(1);
        collateralPool.withdraw(2);
        vm.stopPrank();

        // Verify both withdraws were successful
        assertEq(
            WETH_ERC20.balanceOf(addr1),
            balanceBefore + firstWithdrawAmount + secondWithdrawAmount,
            "Both withdraws should be transferred"
        );

        // Verify both withdraw requests are deleted
        (token1, startTime1, amount1) = collateralPool.tokenWithdraws(addr1, 1);
        (token2, startTime2, amount2) = collateralPool.tokenWithdraws(addr1, 2);
        
        // Verify first withdraw is completely deleted
        assertEq(amount1, 0, "First withdraw amount should be deleted");
        assertEq(address(token1), address(0), "First withdraw token should be deleted");
        assertEq(startTime1, 0, "First withdraw start time should be deleted");

        // Verify second withdraw is completely deleted
        assertEq(amount2, 0, "Second withdraw amount should be deleted");
        assertEq(address(token2), address(0), "Second withdraw token should be deleted");
        assertEq(startTime2, 0, "Second withdraw start time should be deleted");

        assertEq(
            collateralPool.tokenBalance(addr1, WETH_ERC20),
            depositAmount - firstWithdrawAmount - secondWithdrawAmount,
            "Final balance should reflect both withdraws"
        );
    }

    // Tests liquidateBalance fails with insufficient balance
    function testCollateralPool01_liquidateBalance_insufficientLiquidity() public {
        uint depositAmount = 100 * 10**18;
        uint liquidateAmount = depositAmount + 1;

        // Setup: deposit tokens
        vm.startPrank(addr1);
        WETH_ERC20.approve(address(collateralPool), depositAmount);
        collateralPool.deposit(WETH_ERC20, depositAmount);
        vm.stopPrank();

        // Try to liquidate more than available
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(ICollateralPool01.InsufficientLiquidity.selector, depositAmount));
        collateralPool.liquidateBalance(addr1, WETH_ERC20, liquidateAmount, addr2);
    }

    // Tests successful liquidateBalance
    function testCollateralPool01_liquidateBalance_success() public {
        uint depositAmount = 100 * 10**18;
        uint liquidateAmount = 50 * 10**18;

        // Setup: deposit tokens
        vm.startPrank(addr1);
        WETH_ERC20.approve(address(collateralPool), depositAmount);
        collateralPool.deposit(WETH_ERC20, depositAmount);
        vm.stopPrank();

        uint recipientBalanceBefore = WETH_ERC20.balanceOf(addr2);

        // Liquidate balance
        vm.prank(owner);
        collateralPool.liquidateBalance(addr1, WETH_ERC20, liquidateAmount, addr2);

        // Verify token transfer
        assertEq(
            WETH_ERC20.balanceOf(addr2),
            recipientBalanceBefore + liquidateAmount,
            "Tokens should be transferred to recipient"
        );

        // Verify depositor balance is reduced
        assertEq(
            collateralPool.tokenBalance(addr1, WETH_ERC20),
            depositAmount - liquidateAmount,
            "Depositor balance should be reduced by liquidated amount"
        );
    }

    // Tests liquidateBalance event emission
    function testCollateralPool01_liquidateBalance_event() public {
        uint depositAmount = 100 * 10**18;
        uint liquidateAmount = 50 * 10**18;

        // Setup: deposit tokens
        vm.startPrank(addr1);
        WETH_ERC20.approve(address(collateralPool), depositAmount);
        collateralPool.deposit(WETH_ERC20, depositAmount);
        vm.stopPrank();

        // Expect BalanceLiquidated event
        vm.expectEmit(true, false, false, true, address(collateralPool));
        emit ICollateralPool01.BalanceLiquidated(addr1, WETH_ERC20, liquidateAmount, addr2);

        // Liquidate balance
        vm.prank(owner);
        collateralPool.liquidateBalance(addr1, WETH_ERC20, liquidateAmount, addr2);
    }

    // Tests liquidateWithdraw fails with insufficient amount
    function testCollateralPool01_liquidateWithdraw_insufficientLiquidity() public {
        uint depositAmount = 100 * 10**18;
        uint withdrawAmount = 50 * 10**18;
        uint liquidateAmount = withdrawAmount + 1;

        // Setup: deposit and start withdraw
        vm.startPrank(addr1);
        WETH_ERC20.approve(address(collateralPool), depositAmount);
        collateralPool.deposit(WETH_ERC20, depositAmount);
        collateralPool.startWithdraw(WETH_ERC20, withdrawAmount);
        vm.stopPrank();

        // Try to liquidate more than withdraw amount
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(ICollateralPool01.InsufficientLiquidity.selector, withdrawAmount));
        collateralPool.liquidateWithdraw(1, addr1, liquidateAmount, addr2);
    }

    // Tests full liquidation of withdraw request
    function testCollateralPool01_liquidateWithdraw_full() public {
        uint depositAmount = 100 * 10**18;
        uint withdrawAmount = 50 * 10**18;

        // Setup: deposit and start withdraw
        vm.startPrank(addr1);
        WETH_ERC20.approve(address(collateralPool), depositAmount);
        collateralPool.deposit(WETH_ERC20, depositAmount);
        collateralPool.startWithdraw(WETH_ERC20, withdrawAmount);
        vm.stopPrank();

        uint recipientBalanceBefore = WETH_ERC20.balanceOf(addr2);

        // Expect WithdrawLiquidated event
        vm.expectEmit(true, false, false, true, address(collateralPool));
        emit ICollateralPool01.WithdrawLiquidated(addr1, 1, WETH_ERC20, withdrawAmount, addr2);

        // Liquidate full withdraw
        vm.prank(owner);
        collateralPool.liquidateWithdraw(1, addr1, withdrawAmount, addr2);

        // Verify token transfer
        assertEq(
            WETH_ERC20.balanceOf(addr2),
            recipientBalanceBefore + withdrawAmount,
            "Tokens should be transferred to recipient"
        );

        // Verify withdraw request is completely deleted
        (IERC20 token, uint startTime, uint amount) = collateralPool.tokenWithdraws(addr1, 1);
        assertEq(amount, 0, "Withdraw amount should be deleted");
        assertEq(address(token), address(0), "Token should be deleted");
        assertEq(startTime, 0, "Start time should be deleted");
    }

    // Tests partial liquidation of withdraw request
    function testCollateralPool01_liquidateWithdraw_partial() public {
        uint depositAmount = 100 * 10**18;
        uint withdrawAmount = 50 * 10**18;
        uint liquidateAmount = 30 * 10**18;

        // Setup: deposit and start withdraw
        vm.startPrank(addr1);
        WETH_ERC20.approve(address(collateralPool), depositAmount);
        collateralPool.deposit(WETH_ERC20, depositAmount);
        collateralPool.startWithdraw(WETH_ERC20, withdrawAmount);
        vm.stopPrank();

        // Store initial withdraw state
        (IERC20 initialToken, uint initialStartTime,) = collateralPool.tokenWithdraws(addr1, 1);
        uint recipientBalanceBefore = WETH_ERC20.balanceOf(addr2);

        // Expect WithdrawLiquidated event
        vm.expectEmit(true, false, false, true, address(collateralPool));
        emit ICollateralPool01.WithdrawLiquidated(addr1, 1, WETH_ERC20, liquidateAmount, addr2);

        // Liquidate partial withdraw
        vm.prank(owner);
        collateralPool.liquidateWithdraw(1, addr1, liquidateAmount, addr2);

        // Verify token transfer
        assertEq(
            WETH_ERC20.balanceOf(addr2),
            recipientBalanceBefore + liquidateAmount,
            "Tokens should be transferred to recipient"
        );

        // Verify withdraw request is partially reduced
        (IERC20 token, uint startTime, uint amount) = collateralPool.tokenWithdraws(addr1, 1);
        assertEq(amount, withdrawAmount - liquidateAmount, "Withdraw amount should be reduced");
        assertEq(address(token), address(initialToken), "Token should remain unchanged");
        assertEq(startTime, initialStartTime, "Start time should remain unchanged");
    }

    // Tests updateWithdrawPeriod state change and event emission
    function testCollateralPool01_updateWithdrawPeriod() public {
        uint newWithdrawPeriod = 2 days;

        // Expect WithdrawPeriodUpdated event
        vm.expectEmit(false, false, false, true, address(collateralPool));
        emit ICollateralPool01.WithdrawPeriodUpdated(newWithdrawPeriod);

        // Update withdraw period
        vm.prank(owner);
        collateralPool.updateWithdrawPeriod(newWithdrawPeriod);

        // Verify state change
        assertEq(
            collateralPool.withdrawPeriod(),
            newWithdrawPeriod,
            "Withdraw period should be updated"
        );
    }

    // Test updateWithdrawPeriod fails if new period is the same as the old period
    function testCollateralPool01_updateWithdrawPeriod_samePeriod() public {
        uint oldWithdrawPeriod = collateralPool.withdrawPeriod();
        vm.startPrank(owner);
        vm.expectRevert(ICollateralPool01.PeriodNotChanged.selector);
        collateralPool.updateWithdrawPeriod(oldWithdrawPeriod);
        vm.stopPrank();
    }

    // Tests that sending ETH to the contract reverts
    function testCollateralPool01_receive() public {
        address payable _collateralPool = payable(address(collateralPool));

        uint balanceBefore = _collateralPool.balance;

        vm.expectRevert();
        (bool success,) = _collateralPool.call{value: 1 ether}("");
        assertEq(success, true);

        assertEq(_collateralPool.balance, balanceBefore);
    }
}
