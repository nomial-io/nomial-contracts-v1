// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Helper is Test {

  uint256 public BLOCK_JAN_16_2024 = 21_638_600;

  address public WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
  address public USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

  IERC20 public WETH_ERC20 = IERC20(WETH);
  IERC20 public USDC_ERC20 = IERC20(USDC);

  address public ETH_WHALE = 0x00000000219ab540356cBB839Cbe05303d7705Fa;
  address public WETH_WHALE = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
  address public USDC_WHALE = 0x99C9fc46f92E8a1c0deC1b1747d010903E884bE1;
  
  uint public MAX_UINT = 115792089237316195423570985008687907853269984665640564039457584007913129639935;

  function setupAll () public {
    setupFork(BLOCK_JAN_16_2024);
  }
  
  function setupFork (uint blockNumber) public {
    uint fork = vm.createFork(vm.envString("MAINNET_RPC_URL"), blockNumber);
    vm.selectFork(fork);
  }

}
