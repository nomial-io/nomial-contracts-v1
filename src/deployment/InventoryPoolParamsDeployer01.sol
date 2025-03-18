// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {InventoryPoolParams01} from "../InventoryPoolParams01.sol";
import {IInventoryPoolParamsDeployer01} from "./interfaces/IInventoryPoolParamsDeployer01.sol";
import {DeployerLib} from "./DeployerLib.sol";

contract InventoryPoolParamsDeployer01 is IInventoryPoolParamsDeployer01 {

    function deployParamsAddress(
        bytes32 salt,
        address owner,
        bytes calldata paramsInitData
    ) public view returns (address payable addr, bytes memory bytecode) {
        (
            uint baseFee,
            uint baseRate,
            uint rate1,
            uint rate2,
            uint optimalUtilizationRate,
            uint penaltyRate,
            uint penaltyPeriod
        ) = abi.decode(paramsInitData, (uint, uint, uint, uint, uint, uint, uint));

        bytecode = abi.encodePacked(
            type(InventoryPoolParams01).creationCode,
            abi.encode(
                owner, baseFee, baseRate, rate1, rate2, 
                optimalUtilizationRate, penaltyRate, penaltyPeriod
            )
        );

        addr = payable(DeployerLib.addressFromBytecode(address(this), salt, bytecode));
    }

    function deployParams(
        bytes32 salt,
        address owner,
        bytes calldata paramsInitData
    ) public returns (address payable paramsAddress_) {
        (address payable expectedAddr, bytes memory bytecode) = deployParamsAddress(salt, owner, paramsInitData);

        assembly {
            paramsAddress_ := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
        }

        if (paramsAddress_ == address(0)) revert FailedToDeployInventoryPoolParams();
        require(paramsAddress_ == expectedAddr, "Deployed address mismatch");
        
        emit InventoryPoolParamsDeployed(paramsAddress_);
    }
} 