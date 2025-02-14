// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.20;

import {InventoryPool01} from "./InventoryPool01.sol";
import {InventoryPoolParams01} from "./InventoryPoolParams01.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @dev ...
 * ...
 */
contract InventoryPoolDeployer01 {

  event PoolDeployed(address poolAddress);
  event InventoryPoolParamsDeployed(address inventoryPoolParams);

  error FailedToDeployPool();
  error FailedToDeployInventoryPoolParams();

  function poolAddress(
      bytes32 salt,
      IERC20 asset,
      string calldata name,
      string calldata symbol,
      uint initAmount,
      address owner,
      address params
  ) public view returns (address) {
      bytes memory bytecode = type(InventoryPool01).creationCode;
      bytecode = abi.encodePacked(bytecode, abi.encode(asset, name, symbol, initAmount, owner, params));
      return addressFromBytecode(salt, bytecode);
  }

  function inventoryPoolParamsAddress(
      bytes32 salt,
      address owner,
      bytes calldata paramsInitData
  ) public view returns (address) {
      (
          uint baseFee,
          uint baseRate,
          uint rate1,
          uint rate2,
          uint optimalUtilizationRate,
          uint penaltyRate,
          uint penaltyPeriod
      ) = abi.decode(paramsInitData, (uint, uint, uint, uint, uint, uint, uint));

      bytes memory bytecode = type(InventoryPoolParams01).creationCode;
      bytecode = abi.encodePacked(bytecode, abi.encode(owner, baseFee, baseRate, rate1, rate2, optimalUtilizationRate, penaltyRate, penaltyPeriod));
      return addressFromBytecode(salt, bytecode);
  }

  function addressFromBytecode(
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
  ) public returns (address payable poolAddress_, address payable paramsAddress_) {
    paramsAddress_ = deployInventoryPoolParams(salt, owner, paramsInitData);
    poolAddress_ = deployPool(salt, asset, name, symbol, initAmount, owner, paramsAddress_);
  }

  function deployPool(
      bytes32 salt,
      IERC20 asset,
      string calldata name,
      string calldata symbol,
      uint initAmount,
      address owner,
      address paramsAddr
  ) public returns (address payable poolAddress_) {
      bytes memory poolBytecode = type(InventoryPool01).creationCode;
      poolBytecode = abi.encodePacked(poolBytecode, abi.encode(asset, name, symbol, initAmount, owner, paramsAddr));
      
      // transfer initial amount to this contract and approve to pool address before deployment
      address computedPoolAddress = addressFromBytecode(salt, poolBytecode);
      SafeERC20.safeTransferFrom(asset, msg.sender, address(this), initAmount);
      asset.approve(computedPoolAddress, initAmount);

      assembly {
          poolAddress_ := create2(0, add(poolBytecode, 0x20), mload(poolBytecode), salt)
      }

      if (poolAddress_ == address(0)) {
        revert FailedToDeployPool();
      }

      emit PoolDeployed(poolAddress_);
  }

  function deployInventoryPoolParams(
      bytes32 salt,
      address owner,
      bytes calldata paramsInitData
  ) public returns (address payable paramsAddress_) {
      (
          uint baseFee,
          uint baseRate,
          uint rate1,
          uint rate2,
          uint optimalUtilizationRate,
          uint penaltyRate,
          uint penaltyPeriod
      ) = abi.decode(paramsInitData, (uint, uint, uint, uint, uint, uint, uint));
  
      bytes memory paramsBytecode = type(InventoryPoolParams01).creationCode;
      paramsBytecode = abi.encodePacked(paramsBytecode, abi.encode(owner, baseFee, baseRate, rate1, rate2, optimalUtilizationRate, penaltyRate, penaltyPeriod));

      assembly {
          paramsAddress_ := create2(0, add(paramsBytecode, 0x20), mload(paramsBytecode), salt)
      }

      if (paramsAddress_ == address(0)) {
          revert FailedToDeployInventoryPoolParams();
      }

      emit InventoryPoolParamsDeployed(paramsAddress_);
  }

}
