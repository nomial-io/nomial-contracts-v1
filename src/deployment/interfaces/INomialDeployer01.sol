// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IInventoryPoolDeployer01} from "./IInventoryPoolDeployer01.sol";
import {IInventoryPoolParamsDeployer01} from "./IInventoryPoolParamsDeployer01.sol";
import {IInventoryPoolDefaultAccessManagerDeployer01} from "./IInventoryPoolDefaultAccessManagerDeployer01.sol";

interface INomialDeployer01 {
    error ZeroAddress();

    function poolDeployer() external view returns (IInventoryPoolDeployer01);
    function paramsDeployer() external view returns (IInventoryPoolParamsDeployer01);
    function accessManagerDeployer() external view returns (IInventoryPoolDefaultAccessManagerDeployer01);

    function deploy(
        bytes32 salt,
        bytes calldata poolArgs,
        bytes calldata paramsArgs,
        bytes calldata accessManagerArgs,
        address poolFunder
    ) external returns (address payable pool, address payable params, address payable accessManager);

    function deployAddresses(
        bytes32 salt,
        bytes calldata poolArgs,
        bytes calldata paramsArgs,
        bytes calldata accessManagerArgs
    ) external view returns (address payable pool, address payable params, address payable accessManager);
}
