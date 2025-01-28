// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.20;

import {InventoryPool01} from "./InventoryPool01.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @dev ...
 * ...
 */
contract InventoryPoolDeployer01 {

  event PoolDeployed(address poolAddress);

  error FailedToDeployPool();

  function poolAddress(
      bytes32 salt,
      IERC20 asset,
      string memory name,
      string memory symbol,
      uint initAmount,
      address borrowController
  ) public view returns (address) {
      bytes memory bytecode = type(InventoryPool01).creationCode;
      bytecode = abi.encodePacked(bytecode, abi.encode(asset, name, symbol, initAmount, borrowController));
      return poolAddressFromBytecode(salt, bytecode);
  }

  function poolAddressFromBytecode (
    bytes32 salt,
    bytes memory bytecode
  ) public view returns (address) {
      bytes32 bytecodeHash = keccak256(bytecode);
      bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, bytecodeHash));
      return address(uint160(uint256(hash)));
  }

  function deploy(
      bytes32 salt,
      IERC20 asset,
      string memory name,
      string memory symbol,
      uint initAmount,
      address borrowController
  ) public returns (address poolAddress) {
      bytes memory bytecode = type(InventoryPool01).creationCode;
      bytecode = abi.encodePacked(bytecode, abi.encode(asset, name, symbol, initAmount, borrowController));
      
      // transfer initial amount to this contract and approve to pool address before deployment
      address computedPoolAddress = poolAddressFromBytecode(salt, bytecode);
      SafeERC20.safeTransferFrom(asset, msg.sender, address(this), initAmount);
      asset.approve(computedPoolAddress, initAmount);

      assembly {
          poolAddress := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
      }

      if (poolAddress == address(0)) {
        revert FailedToDeployPool();
      }

      emit PoolDeployed(poolAddress);
  }

}
