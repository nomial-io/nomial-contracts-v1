// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {UtilizationBasedRateParams01} from "../src/UtilizationBasedRateParams01.sol";
import {IInventoryPoolParams01} from "../src/interfaces/IInventoryPoolParams01.sol";
import "./Helper.sol";

contract UtilizationBasedRateParams01Test is Test, Helper {
    UtilizationBasedRateParams01 public params;
    address public constant owner = 0xFD1066acf2FC47F3b2DaCec43E76321644dC9928;

    uint constant RAY = 1e27;

    event ParamsUpdated(uint baseFee, uint baseRate, uint rate1, uint rate2, uint optimalUtilizationRate, uint penaltyRate, uint penaltyPeriod);

    function setUp() public {
        setupAll();

        vm.expectEmit();
        emit ParamsUpdated(defaultBaseFee, defaultBaseRate, defaultRate1, defaultRate2, defaultOptimalUtilizationRate, defaultPenaltyRate, defaultPenaltyPeriod);

        params = new UtilizationBasedRateParams01(
            owner,
            defaultBaseFee,
            defaultBaseRate,
            defaultRate1,
            defaultRate2,
            defaultOptimalUtilizationRate,
            defaultPenaltyRate,
            defaultPenaltyPeriod
        );
    }

    // Tests constructor sets base fee correctly
    function testUtilizationBasedRateParams01_baseFee() public {
        assertEq(params.baseFee(), defaultBaseFee, "Base fee should be correctly set");
    }

    // Tests constructor sets penalty rate correctly
    function testUtilizationBasedRateParams01_penaltyRate() public {
        assertEq(params.penaltyRate(), defaultPenaltyRate, "Penalty rate should be correctly set");
    }

    // Tests constructor sets penalty period correctly
    function testUtilizationBasedRateParams01_penaltyPeriod() public {
        assertEq(params.penaltyPeriod(), defaultPenaltyPeriod, "Penalty period should be correctly set");
    }

    // Tests interest rate at zero utilization equals base rate
    function testUtilizationBasedRateParams01_interestRate_zeroUtilization() public {
        uint interestRate = params.interestRate(0);
        assertEq(interestRate, defaultBaseRate, "Interest rate at 0% utilization should equal base rate");
    }

    // Tests interest rate at half optimal utilization
    function testUtilizationBasedRateParams01_interestRate_halfOptimalUtilization() public {
        uint halfOptimal = defaultOptimalUtilizationRate / 2;
        uint interestRate = params.interestRate(halfOptimal);
        uint expectedRate = defaultBaseRate + (defaultRate1 * halfOptimal) / defaultOptimalUtilizationRate;
        assertEq(interestRate, expectedRate, "Interest rate at half optimal should be correctly interpolated");
    }

    // Tests interest rate at optimal utilization point
    function testUtilizationBasedRateParams01_interestRate_optimalUtilization() public {
        uint interestRate = params.interestRate(defaultOptimalUtilizationRate);
        uint expectedRate = defaultBaseRate + defaultRate1;
        assertEq(interestRate, expectedRate, "Interest rate at optimal utilization should equal base rate + rate1");
    }

    // Tests interest rate at full utilization
    function testUtilizationBasedRateParams01_interestRate_fullUtilization() public {
        uint interestRate = params.interestRate(RAY);
        uint expectedRate = defaultBaseRate + defaultRate1 + defaultRate2;
        assertEq(interestRate, expectedRate, "Interest rate at 100% utilization should equal base rate + rate1 + rate2");
    }

    // Tests interest rate between optimal and full utilization
    function testUtilizationBasedRateParams01_interestRate_betweenOptimalAndFull() public {
        uint optToFullDiff = RAY - defaultOptimalUtilizationRate;
        uint utilizationRate = defaultOptimalUtilizationRate + (optToFullDiff * 75) / 100;
        
        uint interestRate = params.interestRate(utilizationRate);
        uint expectedRate = defaultBaseRate + defaultRate1 + 
            (defaultRate2 * (utilizationRate - defaultOptimalUtilizationRate)) / 
            (RAY - defaultOptimalUtilizationRate);

        assertEq(interestRate, expectedRate, "Interest rate should be correctly interpolated between optimal and full");
    }

    // Tests interest rate reverts when utilization exceeds max
    function testUtilizationBasedRateParams01_interestRate_exceedsMaxUtilization() public {
        vm.expectRevert(abi.encodeWithSelector(IInventoryPoolParams01.InvalidUtilizationRate.selector, RAY + 1));
        params.interestRate(RAY + 1);
    }

    // Tests interest rate at maximum utilization
    function testUtilizationBasedRateParams01_interestRate_atMaxUtilization() public {
        uint interestRate = params.interestRate(RAY);
        uint expectedRate = defaultBaseRate + defaultRate1 + defaultRate2;
        assertEq(interestRate, expectedRate, "Interest rate at 100% utilization should be baseRate + rate1 + rate2");
    }

    // Test updateParams emits event
    function testUtilizationBasedRateParams01_updateParams_emitsEvent() public {
        vm.expectEmit();
        emit ParamsUpdated(defaultBaseFee+1, defaultBaseRate+1, defaultRate1+1, defaultRate2+1, defaultOptimalUtilizationRate+1, defaultPenaltyRate+1, defaultPenaltyPeriod+1);

        vm.prank(owner);
        params.updateParams(defaultBaseFee+1, defaultBaseRate+1, defaultRate1+1, defaultRate2+1, defaultOptimalUtilizationRate+1, defaultPenaltyRate+1, defaultPenaltyPeriod+1);
    }

    // Test updateParams is only callable by owner
    function testUtilizationBasedRateParams01_updateParams_onlyOwner() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(1)));
        vm.prank(address(1));
        params.updateParams(defaultBaseFee+1, defaultBaseRate+1, defaultRate1+1, defaultRate2+1, defaultOptimalUtilizationRate+1, defaultPenaltyRate+1, defaultPenaltyPeriod+1);
    }
} 