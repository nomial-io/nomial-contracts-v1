// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import "../src/InventoryPoolParams01.sol";
import "./Helper.sol";

contract InventoryPoolParams01Test is Test, Helper {
    InventoryPoolParams01 public params;
    address public constant owner = 0xFD1066acf2FC47F3b2DaCec43E76321644dC9928;

    function setUp() public {
        setupAll();
        params = new InventoryPoolParams01(
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

    function testInventoryPoolParams01_baseFee() public {
        assertEq(params.baseFee(), defaultBaseFee, "Base fee should be correctly set");
    }

    function testInventoryPoolParams01_penaltyRate() public {
        assertEq(params.penaltyRate(), defaultPenaltyRate, "Penalty rate should be correctly set");
    }

    function testInventoryPoolParams01_penaltyPeriod() public {
        assertEq(params.penaltyPeriod(), defaultPenaltyPeriod, "Penalty period should be correctly set");
    }

    function testInventoryPoolParams01_interestRate_zeroUtilization() public {
        uint interestRate = params.interestRate(0);
        assertEq(interestRate, defaultBaseRate, "Interest rate at 0% utilization should equal base rate");
    }

    function testInventoryPoolParams01_interestRate_halfOptimalUtilization() public {
        uint halfOptimal = defaultOptimalUtilizationRate / 2;
        uint interestRate = params.interestRate(halfOptimal);
        uint expectedRate = defaultBaseRate + (defaultRate1 * halfOptimal) / defaultOptimalUtilizationRate;
        assertEq(interestRate, expectedRate, "Interest rate at half optimal should be correctly interpolated");
    }

    function testInventoryPoolParams01_interestRate_optimalUtilization() public {
        uint interestRate = params.interestRate(defaultOptimalUtilizationRate);
        uint expectedRate = defaultBaseRate + defaultRate1;
        assertEq(interestRate, expectedRate, "Interest rate at optimal utilization should equal base rate + rate1");
    }

    function testInventoryPoolParams01_interestRate_fullUtilization() public {
        uint interestRate = params.interestRate(1e27);
        uint expectedRate = defaultBaseRate + defaultRate1 + defaultRate2;
        assertEq(interestRate, expectedRate, "Interest rate at 100% utilization should equal base rate + rate1 + rate2");
    }

    function testInventoryPoolParams01_interestRate_betweenOptimalAndFull() public {
        uint optToFullDiff = 1e27 - defaultOptimalUtilizationRate;
        uint utilizationRate = defaultOptimalUtilizationRate + (optToFullDiff * 75) / 100;
        
        uint interestRate = params.interestRate(utilizationRate);
        uint expectedRate = defaultBaseRate + defaultRate1 + 
            (defaultRate2 * (utilizationRate - defaultOptimalUtilizationRate)) / 
            (1e27 - defaultOptimalUtilizationRate);

        assertEq(interestRate, expectedRate, "Interest rate should be correctly interpolated between optimal and full");
    }
} 