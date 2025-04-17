// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {InventoryPool01} from "../InventoryPool01.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {DeployerLib} from "./DeployerLib.sol";
import {IInventoryPoolDeployer01} from "./interfaces/IInventoryPoolDeployer01.sol";

contract InventoryPoolDeployer01 is IInventoryPoolDeployer01 {

    function deployPoolAddress(
        bytes32 salt,
        address owner,
        address paramsAddr,
        bytes memory poolArgs
    ) public view returns (address payable addr, bytes memory bytecode) {
        (
            IERC20 asset,
            string memory name,
            string memory symbol,
            uint initAmount,
        ) = abi.decode(poolArgs, (IERC20, string, string, uint, address));

        bytecode = abi.encodePacked(
            type(InventoryPool01).creationCode,
            abi.encode(asset, name, symbol, initAmount, owner, paramsAddr)
        );

        addr = payable(DeployerLib.addressFromBytecode(address(this), salt, bytecode));
    }

    function deployPool(
        bytes32 salt,
        address owner,
        address paramsAddr,
        address poolFunder,
        bytes memory poolArgs
    ) public returns (address payable poolAddress_) {
        (address payable expectedAddr, bytes memory bytecode) = deployPoolAddress(
            salt, owner, paramsAddr, poolArgs
        );

        (
            IERC20 asset,
            string memory name,
            string memory symbol,
            uint initAmount
        ) = abi.decode(poolArgs, (IERC20, string, string, uint));

        asset.transferFrom(poolFunder, address(this), initAmount);
        asset.approve(expectedAddr, initAmount);

        assembly {
            poolAddress_ := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
        }

        if (poolAddress_ == address(0)) revert FailedToDeployPool();
        require(poolAddress_ == expectedAddr, "Deployed address mismatch");

        emit PoolDeployed(poolAddress_);
    }
}
