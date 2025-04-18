// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IInventoryPoolDeployer01 {
    event PoolDeployed(address pool);
    error FailedToDeployPool();

    function deployPoolAddress(
        bytes32 salt,
        address owner,
        address paramsAddr,
        bytes calldata poolArgs
    ) external view returns (address payable addr, bytes memory bytecode);

    function deployPool(
        bytes32 salt,
        address owner,
        address paramsAddr,
        address poolFunder,
        bytes calldata poolArgs
    ) external returns (address payable);
}
