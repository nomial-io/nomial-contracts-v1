// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {OwnableParams01} from "../OwnableParams01.sol";
import {IInventoryPoolParamsDeployer01} from "./interfaces/IInventoryPoolParamsDeployer01.sol";
import {DeployerLib} from "./DeployerLib.sol";

contract OwnableParamsDeployer01 is IInventoryPoolParamsDeployer01 {

    function deployParamsAddress(
        bytes32 salt,
        address owner,
        bytes calldata paramsInitData
    ) public view returns (address payable addr, bytes memory bytecode) {
        (
            uint baseFee,
            uint interestRate,
            uint penaltyRate,
            uint penaltyPeriod
        ) = abi.decode(paramsInitData, (uint, uint, uint, uint));

        bytecode = abi.encodePacked(
            type(OwnableParams01).creationCode,
            abi.encode(baseFee, interestRate, penaltyRate, penaltyPeriod, owner)
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