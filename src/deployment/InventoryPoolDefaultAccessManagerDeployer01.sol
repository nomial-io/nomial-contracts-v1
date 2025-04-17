// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {InventoryPoolDefaultAccessManager01} from "../owners/InventoryPoolDefaultAccessManager01.sol";
import {DeployerLib} from "./DeployerLib.sol";

contract InventoryPoolDefaultAccessManagerDeployer01 {
    error FailedToDeployAccessManager();

    event AccessManagerDeployed(address indexed accessManager);

    function deployAccessManagerAddress(
        bytes32 salt,
        bytes memory deployAccessManagerArgs
    ) public view returns (address payable addr, bytes memory bytecode) {
        bytecode = abi.encodePacked(
            type(InventoryPoolDefaultAccessManager01).creationCode,
            deployAccessManagerArgs
        );

        addr = payable(DeployerLib.addressFromBytecode(address(this), salt, bytecode));
    }

    function deployAccessManager(
        bytes32 salt,
        bytes memory deployAccessManagerArgs
    ) public returns (address payable accessManagerAddress_) {
        (address payable expectedAddr, bytes memory bytecode) = deployAccessManagerAddress(salt, deployAccessManagerArgs);

        assembly {
            accessManagerAddress_ := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
        }

        if (accessManagerAddress_ == address(0)) revert FailedToDeployAccessManager();
        require(accessManagerAddress_ == expectedAddr, "Deployed address mismatch");

        emit AccessManagerDeployed(accessManagerAddress_);
    }
}
