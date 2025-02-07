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
      string calldata name,
      string calldata symbol,
      uint initAmount,
      address owner,
      bytes calldata paramsInitData
  ) public view returns (address) {
      bytes memory bytecode = type(InventoryPool01).creationCode;
      bytecode = abi.encodePacked(bytecode, abi.encode(asset, name, symbol, initAmount, owner, paramsInitData));
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
      string calldata name,
      string calldata symbol,
      uint initAmount,
      address owner,
      bytes calldata paramsInitData
  ) public returns (address payable poolAddress_) {
      bytes memory bytecode = type(InventoryPool01).creationCode;
      bytecode = abi.encodePacked(bytecode, abi.encode(asset, name, symbol, initAmount, owner, paramsInitData));
      
      // transfer initial amount to this contract and approve to pool address before deployment
      address computedPoolAddress = poolAddressFromBytecode(salt, bytecode);
      SafeERC20.safeTransferFrom(asset, msg.sender, address(this), initAmount);
      asset.approve(computedPoolAddress, initAmount);

      assembly {
          poolAddress_ := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
      }

      if (poolAddress_ == address(0)) {
        revert FailedToDeployPool();
      }

      emit PoolDeployed(poolAddress_);
  }

}
