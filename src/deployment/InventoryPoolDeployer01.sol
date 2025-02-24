// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import {InventoryPool01} from "../InventoryPool01.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {DeployerLib} from "./DeployerLib.sol";
import {IInventoryPoolDeployer01} from "./interfaces/IInventoryPoolDeployer01.sol";

contract InventoryPoolDeployer01 is IInventoryPoolDeployer01 {

    function deployPool(
        bytes32 salt,
        IERC20 asset,
        string calldata name,
        string calldata symbol,
        uint initAmount,
        address owner,
        address paramsAddr,
        address poolFunder
    ) public returns (address payable poolAddress_) {
        bytes memory poolBytecode = type(InventoryPool01).creationCode;
        poolBytecode = abi.encodePacked(poolBytecode, abi.encode(
            asset, name, symbol, initAmount, owner, paramsAddr
        ));
        
        address computedPoolAddress = DeployerLib.addressFromBytecode(
            address(this), salt, poolBytecode
        );
        
        SafeERC20.safeTransferFrom(asset, poolFunder, address(this), initAmount);
        asset.approve(computedPoolAddress, initAmount);

        assembly {
            poolAddress_ := create2(0, add(poolBytecode, 0x20), mload(poolBytecode), salt)
        }

        if (poolAddress_ == address(0)) revert FailedToDeployPool();
        emit PoolDeployed(poolAddress_);
    }
} 