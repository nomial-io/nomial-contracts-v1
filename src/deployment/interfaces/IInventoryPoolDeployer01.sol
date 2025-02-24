// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IInventoryPoolDeployer01 {
    event PoolDeployed(address pool);
    error FailedToDeployPool();

    function deployPool(
        bytes32 salt,
        IERC20 asset,
        string calldata name,
        string calldata symbol,
        uint initAmount,
        address owner,
        address paramsAddr,
        address poolFunder
    ) external returns (address payable);

    function deployPoolAddress(
        bytes32 salt,
        IERC20 asset,
        string calldata name,
        string calldata symbol,
        uint initAmount,
        address owner,
        address paramsAddr
    ) external view returns (address payable addr, bytes memory bytecode);
}
