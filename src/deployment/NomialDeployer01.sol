// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IInventoryPoolDeployer01} from "./interfaces/IInventoryPoolDeployer01.sol";
import {IInventoryPoolParamsDeployer01} from "./interfaces/IInventoryPoolParamsDeployer01.sol";
import {INomialDeployer01} from "./interfaces/INomialDeployer01.sol";

contract NomialDeployer01 is INomialDeployer01 {
    IInventoryPoolDeployer01 public immutable poolDeployer;
    IInventoryPoolParamsDeployer01 public immutable paramsDeployer;

    constructor(
        address _poolDeployer,
        address _paramsDeployer
    ) {
        if (_poolDeployer == address(0) || _paramsDeployer == address(0)) revert ZeroAddress();
        
        poolDeployer = IInventoryPoolDeployer01(_poolDeployer);
        paramsDeployer = IInventoryPoolParamsDeployer01(_paramsDeployer);
    }

    function deploy(
        bytes32 salt,
        IERC20 asset,
        string calldata name,
        string calldata symbol,
        uint initAmount,
        address owner,
        bytes calldata paramsInitData,
        address poolFunder
    ) external returns (address payable pool, address payable params) {
        params = paramsDeployer.deployParams(salt, owner, paramsInitData);
        pool = poolDeployer.deployPool(
            salt, 
            asset, 
            name, 
            symbol, 
            initAmount, 
            owner, 
            params,
            poolFunder
        );
    }

    function deployAddresses(
        bytes32 salt,
        IERC20 asset,
        string calldata name,
        string calldata symbol,
        uint initAmount,
        address owner,
        bytes calldata paramsInitData
    ) public view returns (address payable pool, address payable params) {
        // Get params address first since it's needed for pool deployment
        (params,) = paramsDeployer.deployParamsAddress(
            salt,
            owner,
            paramsInitData
        );

        // Get pool address using params address
        (pool,) = poolDeployer.deployPoolAddress(
            salt,
            asset,
            name,
            symbol,
            initAmount,
            owner,
            params
        );
    }
}
