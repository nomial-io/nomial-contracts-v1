// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import "../src/InventoryPool01.sol";
import "../src/InventoryPoolDeployer01.sol";
import "./Helper.sol";

contract InventoryPool01Test is Test, Helper {

    InventoryPoolDeployer01 public inventoryPoolDeployer01;
    InventoryPool01 public usdcInventoryPool;
    InventoryPool01 public wethInventoryPool;
    
    address public constant addr1 = 0x373FB35c5068f49deF8C2A74C0Fb3a82df02C667;
    address public constant addr2 = 0x5Df7C65332BB095B7b108336A4f4eC7E98D66a61;
    address public constant addr3 = 0x380f7480935b3Fb4FD604eC1Becf1361DaFD600f;
    address public constant borrowController = 0xFD1066acf2FC47F3b2DaCec43E76321644dC9928;
    bytes32 public constant salt = hex'beb2decdc94361e6162b2139bbc95204709af34ca0a85c5bb6fde1e70e0f5c7e';

    function setUp () public {
        setupAll();
        inventoryPoolDeployer01 = new InventoryPoolDeployer01();

        vm.startPrank(USDC_WHALE);
        USDC_ERC20.approve(address(inventoryPoolDeployer01), MAX_UINT);
        usdcInventoryPool = InventoryPool01(inventoryPoolDeployer01.deploy(salt, IERC20(USDC), "nomialUSDC", "nmlUSDC", 1 * 10**5, borrowController));
        vm.stopPrank();
    
        vm.startPrank(WETH_WHALE);
        WETH_ERC20.approve(address(inventoryPoolDeployer01), MAX_UINT);
        wethInventoryPool = InventoryPool01(inventoryPoolDeployer01.deploy(salt, IERC20(WETH), "nomialWETH", "nmlWETH", 1 * 10**14, borrowController));
        vm.stopPrank();

        vm.prank(WETH_WHALE);
        WETH_ERC20.approve(address(wethInventoryPool), MAX_UINT);
    }

    function testInventoryPool01_inflationAttack () public {
        vm.prank(WETH_WHALE);
        wethInventoryPool.deposit(1, addr1);
        uint numShares1 = wethInventoryPool.balanceOf(addr1);
        console.log("LP1 shares: ");
        console.logUint(numShares1);
        console.log("pool balance: ");
        console.logUint(IERC20(WETH).balanceOf(address(wethInventoryPool)));
        console.log();

        vm.prank(WETH_WHALE);
        IERC20(WETH).transfer(address(wethInventoryPool), 1 * 10**18);
        console.log("pool balance: ");
        console.logUint(IERC20(WETH).balanceOf(address(wethInventoryPool)));
        console.log();

        vm.prank(WETH_WHALE);
        wethInventoryPool.deposit(1 * 10**18, addr2);
        uint numShares2 = wethInventoryPool.balanceOf(addr2);
        console.log("LP2 shares: ");
        console.logUint(numShares2);
        console.log("pool balance: ");
        console.logUint(IERC20(WETH).balanceOf(address(wethInventoryPool)));
        console.log();

        vm.prank(addr1);
        wethInventoryPool.redeem(numShares1, addr1, addr1);
        uint maxWithdraw = wethInventoryPool.maxWithdraw(addr2);
        vm.prank(addr2);
        wethInventoryPool.withdraw(maxWithdraw, addr2, addr2);
        console.log("LP1 bal: ");
        console.logUint(IERC20(WETH).balanceOf(addr1));
        console.log("LP2 bal: ");
        console.logUint(IERC20(WETH).balanceOf(addr2));
        console.log("pool balance: ");
        console.logUint(IERC20(WETH).balanceOf(address(wethInventoryPool)));
        console.log();
        

        vm.stopPrank();
    }
}
