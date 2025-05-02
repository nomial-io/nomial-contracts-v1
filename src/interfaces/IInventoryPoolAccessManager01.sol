// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {IInventoryPoolParams01} from "./IInventoryPoolParams01.sol";
import {InventoryPool01} from "../InventoryPool01.sol";
import {OwnableParams01} from "../OwnableParams01.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

interface IInventoryPoolAccessManager01 is IAccessControl {
    event SignatureThresholdUpdated(uint16 newSignatureThreshold);

    error SignatureUsed(bytes32 sigHash);
    error SignatureThresholdTooLow(uint16 newSignatureThreshold, uint validatorCount);
    error SignatureThresholdTooHigh(uint16 newSignatureThreshold, uint validatorCount);
    error GrantRoleNotAllowed();
    error RevokeRoleNotAllowed();
    error RenounceRoleNotAllowed();
    error InvalidSignatureCount(uint validSignatures, uint requiredSignatures);
    error ValidatorNotUnique(address validator);
    error ValidatorExists(address validator);
    error ValidatorDoesNotExist(address validator);
    error BorrowerExists(address borrower);
    error BorrowerDoesNotExist(address borrower);
    error ZeroValidatorsNotAllowed();

    function VALIDATOR_ROLE() external view returns (bytes32);
    function BORROWER_ROLE() external view returns (bytes32);
    function validatorCount() external view returns (uint);
    function borrowerCount() external view returns (uint);
    function signatureThreshold() external view returns (uint16);
    function usedSigHashes(bytes32) external view returns (bool);
    function domainSeparator() external view returns (bytes32);
    function hashTypedData(bytes32 structHash) external view returns (bytes32);

    function borrow(InventoryPool01 pool, uint amount, address recipient, uint expiry, bytes32 salt, bytes[] calldata signatures) external;
    function forgiveDebt(InventoryPool01 pool, uint amount, address borrower, bytes32 salt, bytes[] calldata signatures) external;
    function updateBaseFee(OwnableParams01 paramsContract, uint newBaseFee, bytes32 salt, bytes[] calldata signatures) external;
    function updateInterestRate(OwnableParams01 paramsContract, uint newInterestRate, bytes32 salt, bytes[] calldata signatures) external;
    function updatePenaltyRate(OwnableParams01 paramsContract, uint newPenaltyRate, bytes32 salt, bytes[] calldata signatures) external;
    function updatePenaltyPeriod(OwnableParams01 paramsContract, uint newPenaltyPeriod, bytes32 salt, bytes[] calldata signatures) external;
    function upgradeParamsContract(InventoryPool01 pool, IInventoryPoolParams01 paramsContract, bytes32 salt, bytes[] calldata signatures) external;
    function overwriteCoreState(InventoryPool01 pool, uint newStoredAccInterestFactor, uint newLastAccumulatedInterestUpdate, uint newScaledReceivables, bytes32 salt, bytes[] calldata signatures) external;
    function transferOwnership(Ownable ownedContract, address newOwner, bytes32 salt, bytes[] calldata signatures) external;
    function addValidator(address validator, uint16 newSignatureThreshold, bytes32 salt, bytes[] calldata signatures) external;
    function removeValidator(address validator, uint16 newSignatureThreshold, bytes32 salt, bytes[] calldata signatures) external;
    function addBorrower(address borrower, bytes32 salt, bytes[] calldata signatures) external;
    function removeBorrower(address borrower, bytes32 salt, bytes[] calldata signatures) external;
    function setSignatureThreshold(uint16 newSignatureThreshold, bytes32 salt, bytes[] calldata signatures) external;
}
