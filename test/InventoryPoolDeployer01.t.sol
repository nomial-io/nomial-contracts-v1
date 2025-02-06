// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import "../src/InventoryPoolDeployer01.sol";
import "./Helper.sol";

contract InventoryPoolDeployer01Test is Test, Helper {

    InventoryPoolDeployer01 public inventoryPoolDeployer01;
    address public constant borrowController = 0xFD1066acf2FC47F3b2DaCec43E76321644dC9928;
    bytes32 public constant salt = hex'beb2decdc94361e6162b2139bbc95204709af34ca0a85c5bb6fde1e70e0f5c7e';

    function setUp () public {
        setupAll();
        inventoryPoolDeployer01 = new InventoryPoolDeployer01();
    }

    function testInventoryPoolDeployer01_poolAddress () public {

        /*
            // 1 bps (0.01 %)
            baseFee_ = 1 * 1e23;

            // 5% annual rate, per second
            // 5 * 1e25 / (60 * 60 * 24 * 365)
            interestRate_ = 1585489599188229400;

            // 500% annual penalty rate, per second
            // 500 * 1e25 / (60 * 60 * 24 * 365)
            penaltyRate_ = 158548959918822932521;

            // 24 hour penalty period, in seconds
            penaltyPeriod_ = 86400;
        */

        vm.prank(WETH_WHALE);
        address computedAddr = inventoryPoolDeployer01.poolAddress(salt, IERC20(WETH), "nomialWETH", "nmlWETH", 0, borrowController);
        address actualAddr = inventoryPoolDeployer01.deploy(salt, IERC20(WETH), "nomialWETH", "nmlWETH", 0, borrowController);
        assertEq(computedAddr, actualAddr);
    }
}
