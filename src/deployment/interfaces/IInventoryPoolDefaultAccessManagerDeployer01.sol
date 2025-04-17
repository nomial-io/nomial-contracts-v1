// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IInventoryPoolDefaultAccessManagerDeployer01 {
    error FailedToDeployAccessManager();
    event AccessManagerDeployed(address indexed accessManager);

    function deployAccessManagerAddress(
        bytes32 salt,
        bytes calldata accessManagerArgs
    ) external view returns (address payable addr, bytes memory bytecode);

    function deployAccessManager(
        bytes32 salt,
        bytes calldata accessManagerArgs
    ) external returns (address payable accessManagerAddress_);
}
