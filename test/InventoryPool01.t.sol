// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import "../src/InventoryPool01.sol";
import {IInventoryPool01} from "../src/interfaces/IInventoryPool01.sol";
import {IInventoryPoolParams01} from "../src/interfaces/IInventoryPoolParams01.sol";
import "../src/deployment/InventoryPoolDeployer01.sol";
import "../src/deployment/InventoryPoolParamsDeployer01.sol";
import "../src/deployment/NomialDeployer01.sol";
import "./Helper.sol";

contract InventoryPool01Test is Test, Helper {
    using Math for uint256;

    InventoryPoolDeployer01 public poolDeployer;
    InventoryPoolParamsDeployer01 public paramsDeployer;
    NomialDeployer01 public nomialDeployer;
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

    uint constant RAY = 1e27;

    function setUp() public {
        setupAll();
        
        // Deploy the deployers
        poolDeployer = new InventoryPoolDeployer01();
        paramsDeployer = new InventoryPoolParamsDeployer01();
        nomialDeployer = new NomialDeployer01(
            address(poolDeployer),
            address(paramsDeployer)
        );

        // Deploy USDC pool
        vm.startPrank(USDC_WHALE);
        USDC_ERC20.approve(address(poolDeployer), MAX_UINT);
        (address payable usdcPoolAddress,) = nomialDeployer.deploy(
            salt1,
            IERC20(USDC),
            "nomialUSDC",
            "nmlUSDC",
            1 * 10**5,
            poolOwner,
            abi.encode(defaultBaseFee, defaultBaseRate, defaultRate1, defaultRate2, defaultOptimalUtilizationRate, defaultPenaltyRate, defaultPenaltyPeriod),
            USDC_WHALE
        );
        usdcInventoryPool = InventoryPool01(usdcPoolAddress);
        vm.stopPrank();
    
        // Deploy WETH pool
        vm.startPrank(WETH_WHALE);
        WETH_ERC20.approve(address(poolDeployer), MAX_UINT);
        (address payable wethPoolAddress,) = nomialDeployer.deploy(
            salt2,
            IERC20(WETH),
            "nomialWETH",
            "nmlWETH",
            1 * 10**14,
            poolOwner,
            abi.encode(defaultBaseFee, defaultBaseRate, defaultRate1, defaultRate2, defaultOptimalUtilizationRate, defaultPenaltyRate, defaultPenaltyPeriod),
            WETH_WHALE
        );
        wethInventoryPool = InventoryPool01(wethPoolAddress);
        vm.stopPrank();

        vm.prank(WETH_WHALE);
        WETH_ERC20.approve(address(wethInventoryPool), MAX_UINT);
    }

    // Verify that deposit is transferred to dead address on pool deployment
    function testInventoryPool01_deposit_toDeadAddress() public {
        uint depositAmount = 1 * 10**9;

        vm.startPrank(ST_ETH_WHALE);
        ST_ETH_ERC20.approve(address(poolDeployer), MAX_UINT);
        (address payable stEthPoolAddress,) = nomialDeployer.deploy(
            salt3,
            IERC20(ST_ETH),
            "nomialSTETH",
            "nmlSTETH",
            depositAmount,
            poolOwner,
            abi.encode(defaultBaseFee, defaultBaseRate, defaultRate1, defaultRate2, defaultOptimalUtilizationRate, defaultPenaltyRate, defaultPenaltyPeriod),
            ST_ETH_WHALE
        );
        vm.stopPrank();
        
        uint shares = InventoryPool01(stEthPoolAddress).balanceOf(DEAD_ADDRESS);
        assertEq(shares, depositAmount, "ST_ETH deposit should be transferred to dead address");
    }

    // Verify that that if depositAmount is 0, the deposit is not transferred to dead address
    function testInventoryPool01_deposit_zeroAmount() public {
        uint depositAmount = 0;

        vm.startPrank(ST_ETH_WHALE);
        ST_ETH_ERC20.approve(address(poolDeployer), MAX_UINT);
        (address payable stEthPoolAddress,) = nomialDeployer.deploy(
            salt3,
            IERC20(ST_ETH),
            "nomialSTETH",
            "nmlSTETH",
            depositAmount,
            poolOwner,
            abi.encode(defaultBaseFee, defaultBaseRate, defaultRate1, defaultRate2, defaultOptimalUtilizationRate, defaultPenaltyRate, defaultPenaltyPeriod),
            ST_ETH_WHALE
        );
        vm.stopPrank();
        
        uint shares = InventoryPool01(stEthPoolAddress).balanceOf(DEAD_ADDRESS);
        assertEq(shares, 0, "ST_ETH deposit should not be transferred to dead address");
    }

    // Verifies borrow fails when chain ID doesn't match
    function testInventoryPool01_borrow_wrongChainId() public {
        vm.prank(WETH_WHALE);
        wethInventoryPool.deposit(1_000 * 10**18, addr1);

        vm.warp(TEST_TIMESTAMP);
        vm.prank(poolOwner);
        vm.expectRevert(abi.encodeWithSelector(IInventoryPool01.WrongChainId.selector, block.chainid + 1));
        wethInventoryPool.borrow(1*10**18, addr1, addr2, TEST_TIMESTAMP + 1 days, block.chainid + 1);
    }

    // Verifies borrow fails with expired timestamp
    function testInventoryPool01_borrow_expired() public {
        vm.prank(WETH_WHALE);
        wethInventoryPool.deposit(1_000 * 10**18, addr1);

        vm.warp(TEST_TIMESTAMP);
        vm.prank(poolOwner);
        vm.expectRevert(IInventoryPool01.Expired.selector);
        wethInventoryPool.borrow(1*10**18, addr1, addr2, TEST_TIMESTAMP - 1, block.chainid);
    }

    // Checks initial borrow state: base debt, penalty time, and fee calculation
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
        uint expectedDebt = borrowAmount + (borrowAmount * baseFee) / RAY;
        assertEq(baseDebt, expectedDebt, "Base debt should equal borrow amount plus base fee");

        uint penaltyTime = wethInventoryPool.penaltyTime(addr1);
        uint penaltyDebt = wethInventoryPool.penaltyDebt(addr1);
        assertEq(penaltyTime, 0, "Penalty time should be 0");
        assertEq(penaltyDebt, 0, "Penalty debt should be 0");
    }

    // Verifies interest accumulation for borrowed position
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
        uint expectedDebt = initialBaseDebt + (initialBaseDebt * interestRate * 1 hours) / RAY;
        assertEq(newBaseDebt, expectedDebt, "Base debt should reflect 1 hour of interest");
    }

    // Verifies penalty debt calculation after penalty period
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
        uint expectedPenaltyDebt = (baseDebt * penaltyRate * 12 hours) / RAY;
        assertEq(penaltyDebt, expectedPenaltyDebt, "Penalty debt should accumulate at penalty rate");
    }

    // Tests ERC4626 inflation attack mitigation
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

    // Verifies borrowed assets are transferred to recipient
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

    // Verifies Borrowed event is emitted with correct parameters
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

    // Tests interest rate changes with different utilization levels
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
        uint addr1ExpectedDebt = addr1InitialDebt + (addr1InitialDebt * interestRate1 * 1 hours) / RAY;
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
        addr1ExpectedDebt = addr1ExpectedDebt + (addr1ExpectedDebt * interestRate2 * 1 hours) / RAY;
        assertEq(addr1Debt, addr1ExpectedDebt, "First borrower should reflect both interest rate periods");

        // Check borrower 2 debt reflects only the higher rate
        uint addr2Debt = wethInventoryPool.baseDebt(addr2);
        uint addr2ExpectedDebt = addr2InitialDebt + (addr2InitialDebt * interestRate2 * 1 hours) / RAY;
        assertEq(addr2Debt, addr2ExpectedDebt, "Second borrower should reflect only the higher interest rate period");
    }

    // Verifies repay fails with zero amount
    function testInventoryPool01_repay_zeroRepayment() public {
        vm.prank(WETH_WHALE);
        wethInventoryPool.deposit(1_000 * 10**18, poolOwner);

        vm.prank(poolOwner);
        wethInventoryPool.borrow(1 * 10**18, addr1, addr1, TEST_TIMESTAMP + 1 days, block.chainid);

        vm.expectRevert(IInventoryPool01.ZeroRepayment.selector);
        wethInventoryPool.repay(0, addr1);
    }

    // Verifies repay fails when borrower has no debt
    function testInventoryPool01_repay_noDebt() public {
        vm.prank(WETH_WHALE);
        wethInventoryPool.deposit(1_000 * 10**18, poolOwner);

        vm.expectRevert(IInventoryPool01.NoDebt.selector);
        wethInventoryPool.repay(1 * 10**18, addr1);
    }

    // Tests repayment of base debt
    function testInventoryPool01_repay_baseDebt() public {
        vm.prank(WETH_WHALE);
        wethInventoryPool.deposit(1_000 * 10**18, poolOwner);

        vm.warp(TEST_TIMESTAMP);
        
        vm.startPrank(poolOwner);
        wethInventoryPool.borrow(100 * 10**18, addr1, addr1, TEST_TIMESTAMP + 1 days, block.chainid);
        vm.stopPrank();

        // verify initial penalty counter start time is the same as borrow timestamp
        (,uint initialPenaltyCounterStart,) = wethInventoryPool.borrowers(addr1);
        assertEq(initialPenaltyCounterStart, TEST_TIMESTAMP, "Penalty counter should be the same as borrow timestamp");

        // move forward half of the penalty period to accrue some base debt but no penalty debt
        uint penaltyPeriod = wethInventoryPool.params().penaltyPeriod();
        vm.warp(TEST_TIMESTAMP + penaltyPeriod / 2);

        // get base debt
        uint baseDebt = wethInventoryPool.baseDebt(addr1);
        uint partialRepayment = baseDebt / 2;

        // get pool balance before repayment
        uint poolInitialBalance = IERC20(WETH).balanceOf(address(wethInventoryPool));

        // approve and make partial repayment
        vm.startPrank(addr1);
        WETH_ERC20.approve(address(wethInventoryPool), partialRepayment);
        wethInventoryPool.repay(partialRepayment, addr1);
        vm.stopPrank();

        // verify base debt is reduced by half
        assertEq(wethInventoryPool.baseDebt(addr1), baseDebt - partialRepayment, "Base debt should be reduced by half");

        // verify penalty debt is zero
        assertEq(wethInventoryPool.penaltyDebt(addr1), 0, "Penalty debt should be zero");

        // verify penalty time is zero
        assertEq(wethInventoryPool.penaltyTime(addr1), 0, "Penalty time should be zero");

        // verify time since penaltyCounterStart is half of the time elapsed since borrow
        (,uint penaltyCounterStart,) = wethInventoryPool.borrowers(addr1);
        uint timeElapsedSinceBorrow = block.timestamp - initialPenaltyCounterStart;
        uint timeSincePenaltyStart = block.timestamp - penaltyCounterStart;
        assertApproxEqAbs(
            timeSincePenaltyStart,
            timeElapsedSinceBorrow / 2,
            1,
            "Time since penaltyCounterStart should be half of time elapsed since borrow"
        );

        // verify ERC20 transfer to pool
        uint poolFinalBalance = IERC20(WETH).balanceOf(address(wethInventoryPool));
        assertEq(poolFinalBalance - poolInitialBalance, partialRepayment, "Pool should receive the partial base debt payment amount");
    }

    // Tests partial repayment of penalty debt
    function testInventoryPool01_repay_penaltyDebtPartial() public {
        vm.prank(WETH_WHALE);
        wethInventoryPool.deposit(1_000 * 10**18, poolOwner);

        vm.warp(TEST_TIMESTAMP);
        
        vm.startPrank(poolOwner);
        wethInventoryPool.borrow(100 * 10**18, addr1, addr1, TEST_TIMESTAMP + 1 days, block.chainid);
        vm.stopPrank();

        // get initial penalty counter start time
        (,uint initialPenaltyCounterStart,) = wethInventoryPool.borrowers(addr1);
        assertEq(initialPenaltyCounterStart, TEST_TIMESTAMP, "Penalty counter start should be the same as borrow timestamp");

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

        // Verify penalty counter start time is unchanged
        (,uint penaltyCounterStart,) = wethInventoryPool.borrowers(addr1);
        assertEq(penaltyCounterStart, initialPenaltyCounterStart, "Penalty counter should not have changed");
    }

    // Tests repaying all penalty debt plus partial base debt
    function testInventoryPool01_repay_penaltyAndPartialBaseDebt() public {
        vm.prank(WETH_WHALE);
        wethInventoryPool.deposit(1_000 * 10**18, poolOwner);

        vm.warp(TEST_TIMESTAMP);
        
        vm.startPrank(poolOwner);
        wethInventoryPool.borrow(100 * 10**18, addr1, addr1, TEST_TIMESTAMP + 1 days, block.chainid);
        vm.stopPrank();

        // get initial penalty counter start time
        (,uint initialPenaltyCounterStart,) = wethInventoryPool.borrowers(addr1);
        assertEq(initialPenaltyCounterStart, TEST_TIMESTAMP, "Penalty counter start should be the same as borrow timestamp");

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

        // Verify time since penaltyCounterStart is half of the time elapsed since borrow
        (,uint penaltyCounterStart,) = wethInventoryPool.borrowers(addr1);
        uint timeElapsedSinceBorrow = block.timestamp - initialPenaltyCounterStart;
        uint timeSincePenaltyStart = block.timestamp - penaltyCounterStart;
        assertApproxEqAbs(
            timeSincePenaltyStart,
            timeElapsedSinceBorrow / 2,
            1,
            "Time since penaltyCounterStart should be half of time elapsed since borrow"
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

    // Tests full repayment of both penalty and base debt
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

    // Tests handling of repayment amount exceeding total debt
    function testInventoryPool01_repay_baseDebtOverpayment() public {
        vm.warp(TEST_TIMESTAMP);

        vm.startPrank(WETH_WHALE);
        wethInventoryPool.deposit(1_000 * 10**18, poolOwner);
        WETH_ERC20.transfer(addr1, 1 * 10**18);
        vm.stopPrank();
        
        vm.prank(poolOwner);
        wethInventoryPool.borrow(100 * 10**18, addr1, addr1, TEST_TIMESTAMP + 1 days, block.chainid);

        uint baseDebt = wethInventoryPool.baseDebt(addr1);
        uint overpaymentAmount = baseDebt * 2;

        uint poolInitialBalance = IERC20(WETH).balanceOf(address(wethInventoryPool));

        vm.startPrank(addr1);
        WETH_ERC20.approve(address(wethInventoryPool), overpaymentAmount);

        vm.expectEmit(true, false, false, true, address(wethInventoryPool));
        emit IInventoryPool01.BaseDebtRepayment(addr1, baseDebt, baseDebt);
        
        wethInventoryPool.repay(overpaymentAmount, addr1);
        vm.stopPrank();

        assertEq(wethInventoryPool.baseDebt(addr1), 0, "Base debt should be cleared");

        (,uint penaltyCounterStart,) = wethInventoryPool.borrowers(addr1);
        assertEq(penaltyCounterStart, 0, "Penalty counter should be reset");

        uint poolFinalBalance = IERC20(WETH).balanceOf(address(wethInventoryPool));
        assertEq(poolFinalBalance - poolInitialBalance, baseDebt, "Pool should receive only the actual debt amount");
    }

    // Verifies interest factor updates on deposit
    function testInventoryPool01_deposit_updatesAccumulatedInterestFactor() public {
        vm.prank(WETH_WHALE);
        wethInventoryPool.deposit(1_000 * 10**18, addr1);

        vm.prank(poolOwner);
        wethInventoryPool.borrow(100 * 10**18, addr1, addr1, TEST_TIMESTAMP + 1 days, block.chainid);

        uint preDepositAccInterestFactor = wethInventoryPool.accumulatedInterestFactor();

        vm.warp(TEST_TIMESTAMP + 1 hours);

        vm.prank(WETH_WHALE);
        wethInventoryPool.deposit(10 * 10**18, addr2);

        assertTrue(wethInventoryPool.storedAccInterestFactor() > preDepositAccInterestFactor, "Stored interest factor should have increased after deposit");
    }

    // Verifies interest factor updates on withdraw
    function testInventoryPool01_withdraw_updatesAccumulatedInterestFactor() public {
        vm.prank(WETH_WHALE);
        wethInventoryPool.deposit(1_000 * 10**18, addr1);

        vm.prank(poolOwner);
        wethInventoryPool.borrow(100 * 10**18, addr2, addr2, TEST_TIMESTAMP + 1 days, block.chainid);

        uint preWithdrawAccInterestFactor = wethInventoryPool.accumulatedInterestFactor();

        vm.warp(TEST_TIMESTAMP + 1 hours);

        vm.prank(addr1);
        wethInventoryPool.withdraw(10 * 10**18, addr1, addr1);

        assertTrue(wethInventoryPool.storedAccInterestFactor() > preWithdrawAccInterestFactor, "Stored interest factor should have increased after withdraw");
    }

    // Tests withdraw fails with insufficient pool liquidity
    function testInventoryPool01_withdraw_insufficientLiquidity() public {
        vm.prank(WETH_WHALE);
        wethInventoryPool.deposit(1_000 * 10**18, addr1);

        vm.prank(poolOwner);
        wethInventoryPool.borrow(900 * 10**18, addr2, addr2, TEST_TIMESTAMP + 1 days, block.chainid);

        // Try to withdraw more than available liquidity (1000 - 900 = 100 WETH available)
        vm.prank(addr1);
        vm.expectRevert(IInventoryPool01.InsufficientLiquidity.selector);
        wethInventoryPool.withdraw(200 * 10**18, addr1, addr1);
    }

    // Tests owner's ability to forgive debt without asset transfer
    function testInventoryPool01_forgiveDebt() public {
        vm.prank(WETH_WHALE);
        wethInventoryPool.deposit(1_000 * 10**18, poolOwner);

        vm.warp(TEST_TIMESTAMP);

        vm.prank(poolOwner);
        wethInventoryPool.borrow(100 * 10**18, addr1, addr1, TEST_TIMESTAMP + 1 days, block.chainid);

        uint penaltyPeriod = wethInventoryPool.params().penaltyPeriod();
        vm.warp(TEST_TIMESTAMP + penaltyPeriod + 12 hours);

        uint penaltyDebt = wethInventoryPool.penaltyDebt(addr1);
        uint baseDebt = wethInventoryPool.baseDebt(addr1);
        uint poolInitialBalance = IERC20(WETH).balanceOf(address(wethInventoryPool));

        // Non-owner cannot call forgiveDebt
        vm.prank(addr1);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", addr1));
        wethInventoryPool.forgiveDebt(baseDebt + penaltyDebt, addr1);

        vm.startPrank(poolOwner);
        
        // Expect both penalty and base debt repayment events
        vm.expectEmit(true, false, false, true, address(wethInventoryPool));
        emit IInventoryPool01.PenaltyRepayment(addr1, penaltyDebt, penaltyDebt);
        
        vm.expectEmit(true, false, false, true, address(wethInventoryPool));
        emit IInventoryPool01.BaseDebtRepayment(addr1, baseDebt, baseDebt);
        
        wethInventoryPool.forgiveDebt(baseDebt + penaltyDebt, addr1);
        vm.stopPrank();

        // Verify all debt is cleared
        assertEq(wethInventoryPool.penaltyDebt(addr1), 0, "Penalty debt should be cleared");
        assertEq(wethInventoryPool.baseDebt(addr1), 0, "Base debt should be cleared");

        // Verify penalty counter is reset
        (,uint penaltyCounterStart,) = wethInventoryPool.borrowers(addr1);
        assertEq(penaltyCounterStart, 0, "Penalty counter should be reset");

        // Verify no ERC20 transfer occurred
        uint poolFinalBalance = IERC20(WETH).balanceOf(address(wethInventoryPool));
        assertEq(poolFinalBalance, poolInitialBalance, "Pool balance should remain unchanged");
    }

    // Tests owner's ability to upgrade params contract
    function testInventoryPool01_upgradeParamsContract() public {
        // Deploy new params contract
        vm.startPrank(poolOwner);
        address payable newParamsAddress = paramsDeployer.deployParams(
            salt4,
            poolOwner,
            abi.encode(defaultBaseFee, defaultBaseRate, defaultRate1, defaultRate2, defaultOptimalUtilizationRate, defaultPenaltyRate, defaultPenaltyPeriod)
        );
        
        // Expect event emission
        vm.expectEmit(true, true, false, true, address(wethInventoryPool));
        emit IInventoryPool01.ParamsContractUpgraded(IInventoryPoolParams01(newParamsAddress));
        
        // Upgrade params contract
        wethInventoryPool.upgradeParamsContract(IInventoryPoolParams01(newParamsAddress));
        vm.stopPrank();

        // Verify params contract was updated
        assertEq(address(wethInventoryPool.params()), newParamsAddress, "Params contract should be updated");
    }

    // Tests non-owner cannot upgrade params contract
    function testInventoryPool01_upgradeParamsContract_notOwner() public {
        // Deploy new params contract
        vm.prank(poolOwner);
        address payable newParamsAddress = paramsDeployer.deployParams(
            salt4,
            poolOwner,
            abi.encode(defaultBaseFee, defaultBaseRate, defaultRate1, defaultRate2, defaultOptimalUtilizationRate, defaultPenaltyRate, defaultPenaltyPeriod)
        );
        
        // Try to upgrade params contract as non-owner
        vm.prank(addr1);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", addr1));
        wethInventoryPool.upgradeParamsContract(IInventoryPoolParams01(newParamsAddress));
    }

    // Tests error emitted if params contract is not changed
    function testInventoryPool01_upgradeParamsContract_paramsNotChanged() public {
        IInventoryPoolParams01 oldParams = wethInventoryPool.params();

        vm.prank(poolOwner);
        vm.expectRevert(IInventoryPool01.ParamsContractNotChanged.selector);
        wethInventoryPool.upgradeParamsContract(oldParams);
    }

    // Tests receive function reverts ETH transfers
    function testInventoryPool01_receive() public {
        address payable _wethInventoryPool = payable(address(wethInventoryPool));

        uint balanceBefore = _wethInventoryPool.balance;

        vm.expectRevert();
        (bool success,) = _wethInventoryPool.call{value: 1 ether}("");
        assertEq(success, true);

        assertEq(_wethInventoryPool.balance, balanceBefore);
    }
}
