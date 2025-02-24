// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

interface IInventoryPoolParamsDeployer01 {
    event InventoryPoolParamsDeployed(address params);
    error FailedToDeployInventoryPoolParams();

    function deployParams(
        bytes32 salt,
        address owner,
        bytes calldata paramsInitData
    ) external returns (address payable);

    function deployParamsAddress(
        bytes32 salt,
        address owner,
        bytes calldata paramsInitData
    ) external view returns (address payable addr, bytes memory bytecode);
}
