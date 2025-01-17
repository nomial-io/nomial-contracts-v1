// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.20;

import {ERC4626, IERC20, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

/**
 * @dev ...
 * ...
 */
contract InventoryPool01 is ERC4626 {
    constructor(
        IERC20 asset,
        string memory name,
        string memory symbol,
        uint initAmount
    ) ERC4626(IERC20(asset)) ERC20(name, symbol) {
        deposit(initAmount, 0x000000000000000000000000000000000000dEaD);
    }
}
