// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {InventoryPoolDefaultAccessManager01} from "../../src/owners/InventoryPoolDefaultAccessManager01.sol";

contract ValidateSignaturesMock is InventoryPoolDefaultAccessManager01 {
    constructor(
        address admin,
        address[] memory validators,
        uint16 signatureThreshold
    ) InventoryPoolDefaultAccessManager01(admin, validators, signatureThreshold) {}

    function validateSignatures(bytes32 digest, bytes[] calldata signatures) external {
        _validateSignatures(digest, signatures);
    }
} 