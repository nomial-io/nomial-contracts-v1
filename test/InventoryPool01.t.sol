// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import "../src/InventoryPool01.sol";
import "../src/InventoryPoolDeployer01.sol";
import "./Helper.sol";

contract InventoryPool01Test is Test, Helper {
    using Math for uint256;

    InventoryPoolDeployer01 public inventoryPoolDeployer01;
    InventoryPool01 public usdcInventoryPool;
    InventoryPool01 public wethInventoryPool;
    
    address public constant addr1 = 0x373FB35c5068f49deF8C2A74C0Fb3a82df02C667;
    address public constant addr2 = 0x5Df7C65332BB095B7b108336A4f4eC7E98D66a61;
    address public constant addr3 = 0x380f7480935b3Fb4FD604eC1Becf1361DaFD600f;
    address public constant poolOwner = 0xFD1066acf2FC47F3b2DaCec43E76321644dC9928;
    bytes32 public constant salt1 = hex'a9a8bae2fc8ea91bd701a424b988cbefc6e0f6a459baa63e619bc908fef1ad12';
    bytes32 public constant salt2 = hex'95aa895ea6e2d9a504bd372ed1fcd917bb99e683c487a720fbbb456bd4c0e2bf';
    bytes32 public constant salt3 = hex'ed0461bb6636b9669060a1f83779bb5d660330b2a2cd0d04dd3c22533b24aae3';
    bytes32 public constant salt4 = hex'3b9eaf8ca13209dab364d64ca37e15568026112dda9f5dd8d3519338ae882fd7';

    function setUp () public {
        setupAll();
        inventoryPoolDeployer01 = new InventoryPoolDeployer01();

        vm.startPrank(USDC_WHALE);
        USDC_ERC20.approve(address(inventoryPoolDeployer01), MAX_UINT);
        (address payable usdcPoolAddress,) = inventoryPoolDeployer01.deploy(
            salt1,
            IERC20(USDC), "nomialUSDC", "nmlUSDC",
            1 * 10**5,
            poolOwner,
            abi.encode(defaultBaseFee, defaultBaseRate, defaultRate1, defaultRate2, defaultOptimalUtilizationRate, defaultPenaltyRate, defaultPenaltyPeriod)
        );
        usdcInventoryPool = InventoryPool01(usdcPoolAddress);
        vm.stopPrank();
    
        vm.startPrank(WETH_WHALE);
        WETH_ERC20.approve(address(inventoryPoolDeployer01), MAX_UINT);
        (address payable wethPoolAddress,) = inventoryPoolDeployer01.deploy(
            salt2,
            IERC20(WETH), "nomialWETH", "nmlWETH",
            1 * 10**14,
            poolOwner,
            abi.encode(defaultBaseFee, defaultBaseRate, defaultRate1, defaultRate2, defaultOptimalUtilizationRate, defaultPenaltyRate, defaultPenaltyPeriod)
        );
        wethInventoryPool = InventoryPool01(wethPoolAddress);
        vm.stopPrank();

        vm.prank(WETH_WHALE);
        WETH_ERC20.approve(address(wethInventoryPool), MAX_UINT);
    }

    function testInventoryPool01_borrow_wrongChainId() public {
        vm.prank(WETH_WHALE);
        wethInventoryPool.deposit(1_000 * 10**18, addr1);

        vm.warp(TEST_TIMESTAMP);
        vm.prank(poolOwner);
        vm.expectRevert(WrongChainId.selector);
        wethInventoryPool.borrow(1*10**18, addr1, addr2, TEST_TIMESTAMP + 1 days, block.chainid + 1);
    }

    function testInventoryPool01_borrow_expired() public {
        vm.prank(WETH_WHALE);
        wethInventoryPool.deposit(1_000 * 10**18, addr1);

        vm.warp(TEST_TIMESTAMP);
        vm.prank(poolOwner);
        vm.expectRevert(Expired.selector);
        wethInventoryPool.borrow(1*10**18, addr1, addr2, TEST_TIMESTAMP - 1, block.chainid);
    }

    function testInventoryPool01_borrow_initialState() public {
        vm.prank(WETH_WHALE);
        wethInventoryPool.deposit(1_000 * 10**18, addr1);

        uint borrowAmount = 1 * 10**18;
        vm.warp(TEST_TIMESTAMP);
        
        uint baseFee = wethInventoryPool.params().baseFee();
        
        vm.startPrank(poolOwner);
        wethInventoryPool.borrow(borrowAmount, addr1, addr2, TEST_TIMESTAMP + 1 days, block.chainid);
        vm.stopPrank();

        uint baseDebt = wethInventoryPool.baseDebt(addr1);
        uint expectedDebt = borrowAmount + (borrowAmount * baseFee) / 1e27;
        assertEq(baseDebt, expectedDebt, "Base debt should equal borrow amount plus base fee");

        uint penaltyTime = wethInventoryPool.penaltyTime(addr1);
        uint penaltyDebt = wethInventoryPool.penaltyDebt(addr1);
        assertEq(penaltyTime, 0, "Penalty time should be 0");
        assertEq(penaltyDebt, 0, "Penalty debt should be 0");
    }

    function testInventoryPool01_borrow_accumulatedInterest() public {
        vm.prank(WETH_WHALE);
        wethInventoryPool.deposit(1_000 * 10**18, addr1);

        uint borrowAmount = 100 * 10**18;
        vm.warp(TEST_TIMESTAMP);
        
        vm.startPrank(poolOwner);
        wethInventoryPool.borrow(borrowAmount, addr1, addr2, TEST_TIMESTAMP + 1 days, block.chainid);
        vm.stopPrank();

        uint initialBaseDebt = wethInventoryPool.baseDebt(addr1);
        uint utilizationRate = wethInventoryPool.utilizationRate();
        uint interestRate = wethInventoryPool.params().interestRate(utilizationRate);
        
        vm.warp(TEST_TIMESTAMP + 1 hours);
        
        uint newBaseDebt = wethInventoryPool.baseDebt(addr1);
        uint expectedDebt = initialBaseDebt + (initialBaseDebt * interestRate * 1 hours) / 1e27;
        assertEq(newBaseDebt, expectedDebt, "Base debt should reflect 1 hour of interest");
    }

    function testInventoryPool01_borrow_penaltyAfterPeriod() public {
        vm.prank(WETH_WHALE);
        wethInventoryPool.deposit(1_000 * 10**18, addr1);

        uint borrowAmount = 100 * 10**18;
        vm.warp(TEST_TIMESTAMP);
        
        vm.startPrank(poolOwner);
        wethInventoryPool.borrow(borrowAmount, addr1, addr2, TEST_TIMESTAMP + 1 days, block.chainid);
        vm.stopPrank();

        uint penaltyPeriod = wethInventoryPool.params().penaltyPeriod();
        uint penaltyRate = wethInventoryPool.params().penaltyRate();

        vm.warp(TEST_TIMESTAMP + penaltyPeriod + 12 hours);
        
        uint penaltyTime = wethInventoryPool.penaltyTime(addr1);
        assertEq(penaltyTime, 12 hours, "Penalty time should be time elapsed after penalty period");

        uint penaltyDebt = wethInventoryPool.penaltyDebt(addr1);
        uint baseDebt = wethInventoryPool.baseDebt(addr1);
        uint expectedPenaltyDebt = (baseDebt * penaltyRate * 12 hours) / 1e27;
        assertEq(penaltyDebt, expectedPenaltyDebt, "Penalty debt should accumulate at penalty rate");
    }

    function testInventoryPool01_inflationAttack () public {
        // Attacker deposits minimal amount
        vm.prank(WETH_WHALE);
        wethInventoryPool.deposit(1, addr1);
        uint numShares1 = wethInventoryPool.balanceOf(addr1);
        
        // Attacker transfers tokens to pool directly
        vm.prank(WETH_WHALE);
        IERC20(WETH).transfer(address(wethInventoryPool), 1 * 10**18);
        
        // LP deposits large amount
        vm.prank(WETH_WHALE);
        wethInventoryPool.deposit(1 * 10**18, addr2);
        uint numShares2 = wethInventoryPool.balanceOf(addr2);

        // Both LPs withdraw
        vm.prank(addr1);
        wethInventoryPool.redeem(numShares1, addr1, addr1);

        vm.prank(addr2);
        wethInventoryPool.redeem(numShares2, addr2, addr2);
        
        uint addr1Balance = IERC20(WETH).balanceOf(addr1);
        uint addr2Balance = IERC20(WETH).balanceOf(addr2);

        assertEq(addr1Balance, 10000, "Attacker should get a dust amount of WETH");
        assertEq(addr2Balance, 1 * 10**18 - 48, "Second LP should get their deposit minus some dust");
    }

    function testInventoryPool01_borrow_transferToRecipient() public {
        vm.prank(WETH_WHALE);
        wethInventoryPool.deposit(1_000 * 10**18, poolOwner);

        uint borrowAmount = 1 * 10**18;
        uint recipientInitialBalance = IERC20(WETH).balanceOf(addr2);

        vm.prank(poolOwner);
        wethInventoryPool.borrow(borrowAmount, addr1, addr2, TEST_TIMESTAMP + 1 days, block.chainid);

        uint recipientFinalBalance = IERC20(WETH).balanceOf(addr2);
        assertEq(recipientFinalBalance - recipientInitialBalance, borrowAmount, "Recipient should receive the borrowed ERC20 amount");
    }

    function testInventoryPool01_borrow_emitEvent() public {
        vm.prank(WETH_WHALE);
        wethInventoryPool.deposit(1_000 * 10**18, poolOwner);

        uint borrowAmount = 1 * 10**18;
        vm.warp(TEST_TIMESTAMP);

        vm.expectEmit(true, true, false, true, address(wethInventoryPool));
        emit IInventoryPool01.Borrowed(addr1, addr2, borrowAmount);

        vm.prank(poolOwner);
        wethInventoryPool.borrow(borrowAmount, addr1, addr2, TEST_TIMESTAMP + 1 days, block.chainid);
    }

    function testInventoryPool01_borrow_variableInterestRate() public {
        vm.prank(WETH_WHALE);
        wethInventoryPool.deposit(1_000 * 10**18, poolOwner);

        vm.warp(TEST_TIMESTAMP);

        // borrow at very low utilization and interestRate
        vm.prank(poolOwner);
        wethInventoryPool.borrow(1 * 10**18, addr1, addr1, TEST_TIMESTAMP + 1 days, block.chainid);

        uint interestRate1 = wethInventoryPool.params().interestRate(wethInventoryPool.utilizationRate());
        uint addr1InitialDebt = wethInventoryPool.baseDebt(addr1);

        // Move forward 1 hour to accumulate some interest at interestRate1
        vm.warp(TEST_TIMESTAMP + 1 hours);
        
        uint addr1Debt = wethInventoryPool.baseDebt(addr1);
        uint addr1ExpectedDebt = addr1InitialDebt + (addr1InitialDebt * interestRate1 * 1 hours) / 1e27;
        assertEq(addr1Debt, addr1ExpectedDebt, "Expected debt after 1 hour at interestRate1 should match");

        // Large borrow to increase utilization and interestRate
        vm.startPrank(poolOwner);
        wethInventoryPool.borrow(250 * 10**18, poolOwner, poolOwner, TEST_TIMESTAMP + 1 days, block.chainid);
        wethInventoryPool.borrow(3 * 10**18, addr2, addr2, TEST_TIMESTAMP + 1 days, block.chainid);
        vm.stopPrank();

        uint addr2InitialDebt = wethInventoryPool.baseDebt(addr2);

        uint interestRate2 = wethInventoryPool.params().interestRate(wethInventoryPool.utilizationRate());
        uint expectedRate2 = defaultRate1.mulDiv(wethInventoryPool.utilizationRate(), defaultOptimalUtilizationRate);
        assertEq(interestRate2, expectedRate2, "Interest rate should rate1 * utilizationRate / optimalUtilizationRate");

        // Move forward another hour to accumulate interest at the higher rate
        vm.warp(TEST_TIMESTAMP + 2 hours);

        // Check borrower 1 debt reflects both interest rate periods
        addr1Debt = wethInventoryPool.baseDebt(addr1);
        addr1ExpectedDebt = addr1ExpectedDebt + (addr1ExpectedDebt * interestRate2 * 1 hours) / 1e27;
        assertEq(addr1Debt, addr1ExpectedDebt, "First borrower should reflect both interest rate periods");

        // Check borrower 2 debt reflects only the higher rate
        uint addr2Debt = wethInventoryPool.baseDebt(addr2);
        uint addr2ExpectedDebt = addr2InitialDebt + (addr2InitialDebt * interestRate2 * 1 hours) / 1e27;
        assertEq(addr2Debt, addr2ExpectedDebt, "Second borrower should reflect only the higher interest rate period");
    }

    function testInventoryPool01_repay_zeroRepayment() public {
        vm.prank(WETH_WHALE);
        wethInventoryPool.deposit(1_000 * 10**18, poolOwner);

        vm.prank(poolOwner);
        wethInventoryPool.borrow(1 * 10**18, addr1, addr1, TEST_TIMESTAMP + 1 days, block.chainid);

        vm.expectRevert(ZeroRepayment.selector);
        wethInventoryPool.repay(0, addr1);
    }

    function testInventoryPool01_repay_noDebt() public {
        vm.prank(WETH_WHALE);
        wethInventoryPool.deposit(1_000 * 10**18, poolOwner);

        vm.expectRevert(NoDebt.selector);
        wethInventoryPool.repay(1 * 10**18, addr1);
    }

    function testInventoryPool01_repay_penaltyDebtPartial() public {
        vm.prank(WETH_WHALE);
        wethInventoryPool.deposit(1_000 * 10**18, poolOwner);

        vm.warp(TEST_TIMESTAMP);
        
        vm.startPrank(poolOwner);
        wethInventoryPool.borrow(100 * 10**18, addr1, addr1, TEST_TIMESTAMP + 1 days, block.chainid);
        vm.stopPrank();

        // Move past penalty period and accrue some penalty debt
        uint penaltyPeriod = wethInventoryPool.params().penaltyPeriod();
        vm.warp(TEST_TIMESTAMP + penaltyPeriod + 12 hours);
        
        uint penaltyDebt = wethInventoryPool.penaltyDebt(addr1);
        uint partialRepayment = penaltyDebt / 2;  // Repay half of penalty debt

        // Get initial pool balance
        uint poolInitialBalance = IERC20(WETH).balanceOf(address(wethInventoryPool));

        // Approve WETH for repayment
        vm.startPrank(addr1);
        WETH_ERC20.approve(address(wethInventoryPool), partialRepayment);

        // Expect penalty repayment event
        vm.expectEmit(true, false, false, true, address(wethInventoryPool));
        emit IInventoryPool01.PenaltyRepayment(addr1, penaltyDebt, partialRepayment);
        
        wethInventoryPool.repay(partialRepayment, addr1);
        vm.stopPrank();

        // Verify remaining penalty debt
        assertEq(wethInventoryPool.penaltyDebt(addr1), penaltyDebt - partialRepayment, "Remaining penalty debt should be half");

        // Verify ERC20 transfer to pool
        uint poolFinalBalance = IERC20(WETH).balanceOf(address(wethInventoryPool));
        assertEq(poolFinalBalance - poolInitialBalance, partialRepayment, "Pool should receive the penalty payment amount");
    }

    function testInventoryPool01_repay_penaltyAndPartialBaseDebt() public {
        vm.prank(WETH_WHALE);
        wethInventoryPool.deposit(1_000 * 10**18, poolOwner);

        vm.warp(TEST_TIMESTAMP);
        
        vm.startPrank(poolOwner);
        wethInventoryPool.borrow(100 * 10**18, addr1, addr1, TEST_TIMESTAMP + 1 days, block.chainid);
        vm.stopPrank();

        // Move past penalty period and accrue some penalty debt
        uint penaltyPeriod = wethInventoryPool.params().penaltyPeriod();
        vm.warp(TEST_TIMESTAMP + penaltyPeriod + 12 hours);
        
        uint penaltyDebt = wethInventoryPool.penaltyDebt(addr1);
        uint baseDebt = wethInventoryPool.baseDebt(addr1);
        uint totalPayment = penaltyDebt + (baseDebt / 2);  // Pay all penalty debt plus half of base debt

        // Transfer WETH to addr1 for repayment
        vm.prank(WETH_WHALE);
        WETH_ERC20.transfer(addr1, totalPayment);

        // Get initial balances
        uint poolInitialBalance = IERC20(WETH).balanceOf(address(wethInventoryPool));

        // Approve WETH for repayment
        vm.startPrank(addr1);
        WETH_ERC20.approve(address(wethInventoryPool), totalPayment);

        // Expect penalty repayment event
        vm.expectEmit(true, false, false, true, address(wethInventoryPool));
        emit IInventoryPool01.PenaltyRepayment(addr1, penaltyDebt, penaltyDebt);
        
        // Expect base debt repayment event
        vm.expectEmit(true, false, false, true, address(wethInventoryPool));
        emit IInventoryPool01.BaseDebtRepayment(addr1, baseDebt, baseDebt / 2);
        
        wethInventoryPool.repay(totalPayment, addr1);
        vm.stopPrank();

        // Verify penalty debt is cleared
        assertEq(wethInventoryPool.penaltyDebt(addr1), 0, "No penalty debt should remain");

        // Verify time since penaltyCounterStart is half of penalty period
        (,uint penaltyCounterStart,) = wethInventoryPool.borrowers(addr1);
        uint timeSincePenaltyStart = block.timestamp - penaltyCounterStart;
        assertApproxEqAbs(
            timeSincePenaltyStart,
            penaltyPeriod / 2,
            1,
            "Time since penaltyCounterStart should be half of penalty period"
        );

        // Verify base debt is partially paid
        uint expectedRemainingDebt = baseDebt / 2;
        assertApproxEqAbs(
            wethInventoryPool.baseDebt(addr1),
            expectedRemainingDebt,
            1,
            "Half of base debt should remain"
        );

        // Verify ERC20 transfer to pool
        uint poolFinalBalance = IERC20(WETH).balanceOf(address(wethInventoryPool));
        assertEq(poolFinalBalance - poolInitialBalance, totalPayment, "Pool should receive the total payment amount");
    }

    function testInventoryPool01_repay_fullPenaltyAndBaseDebt() public {
        vm.warp(TEST_TIMESTAMP);

        vm.startPrank(WETH_WHALE);
        wethInventoryPool.deposit(1_000 * 10**18, poolOwner);
        WETH_ERC20.transfer(addr1, 1 * 10**18);
        vm.stopPrank();
        
        vm.prank(poolOwner);
        wethInventoryPool.borrow(100 * 10**18, addr1, addr1, TEST_TIMESTAMP + 1 days, block.chainid);

        // Move past penalty period and accrue some penalty debt
        uint penaltyPeriod = wethInventoryPool.params().penaltyPeriod();
        vm.warp(TEST_TIMESTAMP + penaltyPeriod + 12 hours);
        
        uint penaltyDebt = wethInventoryPool.penaltyDebt(addr1);
        uint baseDebt = wethInventoryPool.baseDebt(addr1);

        // Pay all penalty debt plus all base debt
        uint totalPayment = penaltyDebt + baseDebt;

        uint poolInitialBalance = IERC20(WETH).balanceOf(address(wethInventoryPool));

        vm.startPrank(addr1);
        WETH_ERC20.approve(address(wethInventoryPool), totalPayment);

        vm.expectEmit(true, false, false, true, address(wethInventoryPool));
        emit IInventoryPool01.PenaltyRepayment(addr1, penaltyDebt, penaltyDebt);

        vm.expectEmit(true, false, false, true, address(wethInventoryPool));
        emit IInventoryPool01.BaseDebtRepayment(addr1, baseDebt, baseDebt);
        
        wethInventoryPool.repay(totalPayment, addr1);
        vm.stopPrank();

        assertEq(wethInventoryPool.penaltyDebt(addr1), 0, "No penalty debt should remain");
        assertEq(wethInventoryPool.baseDebt(addr1), 0, "No base debt should remain");

        (,uint penaltyCounterStart,) = wethInventoryPool.borrowers(addr1);
        assertEq(penaltyCounterStart, 0, "Penalty counter should be reset");

        uint poolFinalBalance = IERC20(WETH).balanceOf(address(wethInventoryPool));
        assertEq(poolFinalBalance - poolInitialBalance, totalPayment, "Pool should receive the total payment amount");
    }
}
