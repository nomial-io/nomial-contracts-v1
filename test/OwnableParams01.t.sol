// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {OwnableParams01} from "../src/OwnableParams01.sol";
import "./Helper.sol";

contract OwnableParams01Test is Test, Helper {
    OwnableParams01 public params;
    address public constant owner = address(1);
    address public constant nonOwner = address(2);

    uint defaultInterestRate = defaultRate1;

    uint constant RAY = 1e27;

    event BaseFeeUpdated(uint oldBaseFee, uint newBaseFee);
    event InterestRateUpdated(uint oldInterestRate, uint newInterestRate);
    event PenaltyRateUpdated(uint oldPenaltyRate, uint newPenaltyRate);
    event PenaltyPeriodUpdated(uint oldPenaltyPeriod, uint newPenaltyPeriod);

    function setUp() public {
        vm.startPrank(owner);
        params = new OwnableParams01(
            defaultBaseFee,
            defaultInterestRate,
            defaultPenaltyRate,
            defaultPenaltyPeriod,
            owner
        );
        vm.stopPrank();
    }

    function testOwnableParams01_constructor() public {
        assertEq(params.baseFee(), defaultBaseFee, "Base fee should be set correctly");
        assertEq(params.interestRate(0), defaultInterestRate, "Interest rate should be set correctly");
        assertEq(params.penaltyRate(), defaultPenaltyRate, "Penalty rate should be set correctly");
        assertEq(params.penaltyPeriod(), defaultPenaltyPeriod, "Penalty period should be set correctly");
        assertEq(params.owner(), owner, "Owner should be set correctly");
    }

    function testOwnableParams01_updateBaseFee() public {
        uint newBaseFee = 2 * defaultBaseFee;
        
        vm.expectEmit(false, false, false, true, address(params));
        emit BaseFeeUpdated(defaultBaseFee, newBaseFee);
        
        vm.prank(owner);
        params.updateBaseFee(newBaseFee);
        
        assertEq(params.baseFee(), newBaseFee, "Base fee should be updated");
    }

    function testOwnableParams01_updateBaseFee_notOwner() public {
        uint newBaseFee = 2 * defaultBaseFee;
        
        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", nonOwner));
        params.updateBaseFee(newBaseFee);
        
        assertEq(params.baseFee(), defaultBaseFee, "Base fee should remain unchanged");
    }

    function testOwnableParams01_updateInterestRate() public {
        uint newInterestRate = 2 * defaultInterestRate;
        
        vm.expectEmit(false, false, false, true, address(params));
        emit InterestRateUpdated(defaultInterestRate, newInterestRate);
        
        vm.prank(owner);
        params.updateInterestRate(newInterestRate);
        
        assertEq(params.interestRate(0), newInterestRate, "Interest rate should be updated");
    }

    function testOwnableParams01_updateInterestRate_notOwner() public {
        uint newInterestRate = 2 * defaultInterestRate;
        
        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", nonOwner));
        params.updateInterestRate(newInterestRate);
        
        assertEq(params.interestRate(0), defaultInterestRate, "Interest rate should remain unchanged");
    }

    function testOwnableParams01_updatePenaltyRate() public {
        uint newPenaltyRate = 2 * defaultPenaltyRate;
        
        vm.expectEmit(false, false, false, true, address(params));
        emit PenaltyRateUpdated(defaultPenaltyRate, newPenaltyRate);
        
        vm.prank(owner);
        params.updatePenaltyRate(newPenaltyRate);
        
        assertEq(params.penaltyRate(), newPenaltyRate, "Penalty rate should be updated");
    }

    function testOwnableParams01_updatePenaltyRate_notOwner() public {
        uint newPenaltyRate = 2 * defaultPenaltyRate;
        
        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", nonOwner));
        params.updatePenaltyRate(newPenaltyRate);
        
        assertEq(params.penaltyRate(), defaultPenaltyRate, "Penalty rate should remain unchanged");
    }

    function testOwnableParams01_updatePenaltyPeriod() public {
        uint newPenaltyPeriod = 2 * defaultPenaltyPeriod;
        
        vm.expectEmit(false, false, false, true, address(params));
        emit PenaltyPeriodUpdated(defaultPenaltyPeriod, newPenaltyPeriod);
        
        vm.prank(owner);
        params.updatePenaltyPeriod(newPenaltyPeriod);
        
        assertEq(params.penaltyPeriod(), newPenaltyPeriod, "Penalty period should be updated");
    }

    function testOwnableParams01_updatePenaltyPeriod_notOwner() public {
        uint newPenaltyPeriod = 2 * defaultPenaltyPeriod;
        
        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", nonOwner));
        params.updatePenaltyPeriod(newPenaltyPeriod);
        
        assertEq(params.penaltyPeriod(), defaultPenaltyPeriod, "Penalty period should remain unchanged");
    }

    function testOwnableParams01_interestRate_ignoresUtilization() public {
        // Interest rate should be constant regardless of utilization
        uint rate1 = params.interestRate(0);
        uint rate2 = params.interestRate(RAY / 2); // 50% utilization
        uint rate3 = params.interestRate(RAY);     // 100% utilization
        
        assertEq(rate1, rate2, "Interest rate should be constant");
        assertEq(rate2, rate3, "Interest rate should be constant");
        assertEq(rate1, defaultInterestRate, "Interest rate should match default");
    }
}
