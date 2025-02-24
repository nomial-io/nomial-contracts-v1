// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import {InventoryPoolParams01} from "../InventoryPoolParams01.sol";
import {IInventoryPoolParamsDeployer01} from "./interfaces/IInventoryPoolParamsDeployer01.sol";

contract InventoryPoolParamsDeployer01 is IInventoryPoolParamsDeployer01 {

    function deployParams(
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
        paramsBytecode = abi.encodePacked(paramsBytecode, abi.encode(
            owner, baseFee, baseRate, rate1, rate2, 
            optimalUtilizationRate, penaltyRate, penaltyPeriod
        ));

        assembly {
            paramsAddress_ := create2(0, add(paramsBytecode, 0x20), mload(paramsBytecode), salt)
        }

        if (paramsAddress_ == address(0)) revert FailedToDeployInventoryPoolParams();
        emit InventoryPoolParamsDeployed(paramsAddress_);
    }
} 