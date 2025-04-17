// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IInventoryPoolDeployer01} from "./interfaces/IInventoryPoolDeployer01.sol";
import {IInventoryPoolParamsDeployer01} from "./interfaces/IInventoryPoolParamsDeployer01.sol";
import {INomialDeployer01} from "./interfaces/INomialDeployer01.sol";
import {IInventoryPoolDefaultAccessManagerDeployer01} from "./interfaces/IInventoryPoolDefaultAccessManagerDeployer01.sol";

contract NomialDeployer01 is INomialDeployer01 {
    IInventoryPoolDeployer01 public immutable poolDeployer;
    IInventoryPoolParamsDeployer01 public immutable paramsDeployer;
    IInventoryPoolDefaultAccessManagerDeployer01 public immutable accessManagerDeployer;

    constructor(
        address _poolDeployer,
        address _paramsDeployer,
        address _accessManagerDeployer
    ) {
        if (_poolDeployer == address(0) || _paramsDeployer == address(0) || _accessManagerDeployer == address(0)) revert ZeroAddress();
        
        poolDeployer = IInventoryPoolDeployer01(_poolDeployer);
        paramsDeployer = IInventoryPoolParamsDeployer01(_paramsDeployer);
        accessManagerDeployer = IInventoryPoolDefaultAccessManagerDeployer01(_accessManagerDeployer);
    }

    function deploy(
        bytes32 salt,
        bytes memory accessManagerArgs,
        bytes memory deployParamsArgs,
        bytes memory deployPoolArgs,
        address poolFunder
    ) external returns (address payable pool, address payable params, address payable accessManager) {
        accessManager = accessManagerDeployer.deployAccessManager(salt, accessManagerArgs);
        params = paramsDeployer.deployParams(
            salt, 
            accessManager, // owned by access manager
            deployParamsArgs
        );
        pool = poolDeployer.deployPool(
            salt, 
            accessManager, // owned by access manager
            params, // uses deployed params contract
            poolFunder,
            deployPoolArgs
        );
    }

    function deployAddresses(
        bytes32 salt,
        bytes memory accessManagerArgs,
        bytes memory paramsArgs,
        bytes memory poolArgs
    ) public view returns (address payable pool, address payable params, address payable accessManager) {
        // Get access manager address first since it's needed for pool deployment
        (accessManager,) = accessManagerDeployer.deployAccessManagerAddress(salt, accessManagerArgs);  

        // Get params address first since it's needed for pool deployment
        (params,) = paramsDeployer.deployParamsAddress(
            salt,
            accessManager, // owned by access manager
            paramsArgs
        );

        // Get pool address using params address
        (pool,) = poolDeployer.deployPoolAddress(
            salt,
            accessManager, // owned by access manager
            params, // uses deployed params contract
            poolArgs
        );
    }
}

