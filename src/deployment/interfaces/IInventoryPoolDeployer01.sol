// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IInventoryPoolDeployer01 {
    event PoolDeployed(address poolAddress);
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
    ) external returns (address payable poolAddress_);
}
