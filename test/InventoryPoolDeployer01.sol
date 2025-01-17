// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import "../src/InventoryPoolDeployer01.sol";
import "./Helper.sol";

contract InventoryPoolDeployer01Test is Test, Helper {

    InventoryPoolDeployer01 public inventoryPoolDeployer01;

    bytes32 public constant salt = hex'beb2decdc94361e6162b2139bbc95204709af34ca0a85c5bb6fde1e70e0f5c7e';

    function setUp () public {
        setupAll();
        inventoryPoolDeployer01 = new InventoryPoolDeployer01();
    }

    function testInventoryPoolDeployer01_poolAddress () public {
        vm.prank(WETH_WHALE);
        address computedAddr = inventoryPoolDeployer01.poolAddress(salt, IERC20(WETH), "nomialWETH", "nmlWETH", 0);
        address actualAddr = inventoryPoolDeployer01.deploy(salt, IERC20(WETH), "nomialWETH", "nmlWETH", 0);
        assertEq(computedAddr, actualAddr);
    }
}
