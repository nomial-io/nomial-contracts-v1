// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IInventoryPoolDeployer01} from "./IInventoryPoolDeployer01.sol";
import {IInventoryPoolParamsDeployer01} from "./IInventoryPoolParamsDeployer01.sol";

interface INomialDeployer01 {
    error ZeroAddress();

    function poolDeployer() external view returns (IInventoryPoolDeployer01);
    function paramsDeployer() external view returns (IInventoryPoolParamsDeployer01);

    function deploy(
        bytes32 salt,
        IERC20 asset,
        string calldata name,
        string calldata symbol,
        uint initAmount,
        address owner,
        bytes calldata paramsInitData,
        address poolFunder
    ) external returns (address payable pool, address payable params);
}
