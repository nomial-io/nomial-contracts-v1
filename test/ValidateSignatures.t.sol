// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {ValidateSignaturesMock} from "./mocks/ValidateSignaturesMock.sol";
import {InventoryPoolDefaultAccessManager01} from "../src/owners/InventoryPoolDefaultAccessManager01.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import "./Helper.sol";

contract ValidateSignaturesTest is Test, Helper {
    ValidateSignaturesMock public validateSignatures;
    
    address public constant admin = address(1);
    uint256 public constant validator1_pk = 0x3;
    uint256 public constant validator2_pk = 0x4;
    uint256 public constant validator3_pk = 0x5;
    uint256 public constant nonValidator_pk = 0x999;
    
    address public validator1;
    address public validator2;
    address public validator3;
    address public nonValidator;
    
    address[] public validators;
    address[] public borrowers;
    uint16 public constant signatureThreshold = 2;
    bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");

    function setUp() public {
        validator1 = vm.addr(validator1_pk);
        validator2 = vm.addr(validator2_pk);
        validator3 = vm.addr(validator3_pk);
        nonValidator = vm.addr(nonValidator_pk);

        validators = new address[](3);
        validators[0] = validator1;
        validators[1] = validator2;
        validators[2] = validator3;

        validateSignatures = new ValidateSignaturesMock(
            admin,
            validators,
            borrowers,
            signatureThreshold
        );
    }

    function test_validateSignatures_success() public {
        bytes32 digest = keccak256("test message");
        
        uint256[] memory privKeys = new uint256[](2);
        privKeys[0] = validator1_pk;
        privKeys[1] = validator2_pk;

        bytes[] memory signatures = getSignaturesFromKeys(digest, privKeys);

        // Should succeed with 2 valid signatures
        validateSignatures.validateSignatures(digest, signatures);
    }

    function test_validateSignatures_insufficientSignaturesReverts() public {
        bytes32 digest = keccak256("test message");
        
        uint256[] memory privKeys = new uint256[](1);
        privKeys[0] = validator1_pk;

        bytes[] memory signatures = getSignaturesFromKeys(digest, privKeys);

        // Should revert with InvalidSignatureCount
        vm.expectRevert(abi.encodeWithSelector(
            InventoryPoolDefaultAccessManager01.InvalidSignatureCount.selector,
            1,
            signatureThreshold
        ));
        validateSignatures.validateSignatures(digest, signatures);
    }

    function test_validateSignatures_duplicateSignerReverts() public {
        bytes32 digest = keccak256("test message");
        
        uint256[] memory privKeys = new uint256[](2);
        privKeys[0] = validator1_pk;
        privKeys[1] = validator1_pk;

        bytes[] memory signatures = getSignaturesFromKeys(digest, privKeys);

        // Should revert with ValidatorNotUnique
        vm.expectRevert(abi.encodeWithSelector(
            InventoryPoolDefaultAccessManager01.ValidatorNotUnique.selector,
            validator1
        ));
        validateSignatures.validateSignatures(digest, signatures);
    }

    function test_validateSignatures_nonValidatorSignatureReverts() public {
        bytes32 digest = keccak256("test message");
        
        uint256[] memory privKeys = new uint256[](2);
        privKeys[0] = validator1_pk;
        privKeys[1] = nonValidator_pk;

        bytes[] memory signatures = getSignaturesFromKeys(digest, privKeys);

        // Should revert with AccessControlUnauthorizedAccount
        vm.expectRevert(abi.encodeWithSelector(
            IAccessControl.AccessControlUnauthorizedAccount.selector,
            nonValidator,
            VALIDATOR_ROLE
        ));
        validateSignatures.validateSignatures(digest, signatures);
    }

    function test_validateSignatures_signatureReplayReverts() public {
        bytes32 digest = keccak256("test message");
        
        uint256[] memory privKeys = new uint256[](2);
        privKeys[0] = validator1_pk;
        privKeys[1] = validator2_pk;

        bytes[] memory signatures = getSignaturesFromKeys(digest, privKeys);

        // First call should succeed
        validateSignatures.validateSignatures(digest, signatures);

        // Second call with same digest should revert
        vm.expectRevert(abi.encodeWithSelector(
            InventoryPoolDefaultAccessManager01.SignatureUsed.selector,
            digest
        ));
        validateSignatures.validateSignatures(digest, signatures);
    }

    function test_validateSignatures_allValidatorsSign() public {
        bytes32 digest = keccak256("test message");
        
        uint256[] memory privKeys = new uint256[](3);
        privKeys[0] = validator1_pk;
        privKeys[1] = validator2_pk;
        privKeys[2] = validator3_pk;

        bytes[] memory signatures = getSignaturesFromKeys(digest, privKeys);

        // Should succeed with all 3 valid signatures
        validateSignatures.validateSignatures(digest, signatures);
    }

    function test_validateSignatures_seenSignersClearedOnSuccess() public {
        bytes32 digest1 = keccak256("test message 1");
        bytes32 digest2 = keccak256("test message 2");
        
        uint256[] memory privKeys = new uint256[](2);
        privKeys[0] = validator1_pk;
        privKeys[1] = validator2_pk;

        bytes[] memory signatures = getSignaturesFromKeys(digest1, privKeys);

        // First validation should succeed
        validateSignatures.validateSignatures(digest1, signatures);

        // Same validators should be able to sign a different digest
        signatures = getSignaturesFromKeys(digest2, privKeys);
        validateSignatures.validateSignatures(digest2, signatures);
    }
} 