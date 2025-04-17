// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {AccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IInventoryPoolParams01} from "../interfaces/IInventoryPoolParams01.sol";
import {OwnableParams01} from "../OwnableParams01.sol";
import {InventoryPool01} from "../InventoryPool01.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

/**
 * @title InventoryPoolDefaultAccessManager01
 * @notice Access control contract for management of InventoryPool01 contracts
 * @dev Implements a multi-signature validator system where a threshold of validator signatures
 * is required for all operations. The contract uses EIP-712 for secure message signing and
 * implements replay protection through signature tracking.
 */
contract InventoryPoolDefaultAccessManager01 is AccessControlEnumerable, EIP712 {
    bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");

    bytes32 public constant BORROW_TYPEHASH = keccak256("Borrow(address pool,address borrower,uint256 amount,address recipient,uint256 expiry,uint256 chainId,bytes32 salt)");
    bytes32 public constant FORGIVE_DEBT_TYPEHASH = keccak256("ForgiveDebt(address pool,uint256 amount,address borrower)");
    bytes32 public constant ADD_VALIDATOR_TYPEHASH = keccak256("AddValidator(address validator,uint16 signatureThreshold)");
    bytes32 public constant REMOVE_VALIDATOR_TYPEHASH = keccak256("RemoveValidator(address validator,uint16 signatureThreshold)");
    bytes32 public constant UPDATE_BASE_FEE_TYPEHASH = keccak256("UpdateBaseFee(address paramsContract,uint256 newBaseFee)");
    bytes32 public constant UPDATE_INTEREST_RATE_TYPEHASH = keccak256("UpdateInterestRate(address paramsContract,uint256 newInterestRate)");
    bytes32 public constant UPDATE_PENALTY_RATE_TYPEHASH = keccak256("UpdatePenaltyRate(address paramsContract,uint256 newPenaltyRate)");
    bytes32 public constant UPDATE_PENALTY_PERIOD_TYPEHASH = keccak256("UpdatePenaltyPeriod(address paramsContract,uint256 newPenaltyPeriod)");
    bytes32 public constant UPGRADE_PARAMS_CONTRACT_TYPEHASH = keccak256("UpgradeParamsContract(address pool,address paramsContract)");
    bytes32 public constant OVERWRITE_CORE_STATE_TYPEHASH = keccak256("OverwriteCoreState(address pool,uint256 newStoredAccInterestFactor,uint256 newLastAccumulatedInterestUpdate,uint256 newScaledReceivables)");
    bytes32 public constant TRANSFER_OWNERSHIP_TYPEHASH = keccak256("TransferOwnership(address ownedContract,address newOwner)");
    bytes32 public constant SET_SIGNATURE_THRESHOLD_TYPEHASH = keccak256("SetSignatureThreshold(uint16 newSignatureThreshold)");
    event SignatureThresholdUpdated(uint16 newSignatureThreshold);

    error SignatureUsed(bytes32 sigHash);
    error SignatureThresholdTooLow(uint16 newSignatureThreshold, uint16 validatorCount);
    error GrantRoleNotAllowed();
    error RevokeRoleNotAllowed();
    error InvalidSignatureCount(uint validSignatures, uint requiredSignatures);
    error ValidatorNotUnique(address validator);

    // Track used signatures to prevent replay
    mapping(bytes32 => bool) public usedSigHashes;

    uint16 public validatorCount;
    uint16 public signatureThreshold;

    mapping(bytes32 => mapping(address => bool)) private _seenSigners;

    /**
     * @notice Initializes the contract with an admin and initial set of validators
     * @dev Sets up the initial validator set and signature threshold. The threshold must be greater
     * than half the number of validators.
     * @param admin Address to be granted the DEFAULT_ADMIN_ROLE
     * @param validators Array of addresses to be granted the VALIDATOR_ROLE
     * @param signatureThreshold_ The minimum number of validator signatures required for operations
     */
    constructor(address admin, address[] memory validators, uint16 signatureThreshold_) EIP712("InventoryPoolDefaultAccessManager01", "1") {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        validatorCount = uint16(validators.length);
        for (uint i = 0; i < validators.length; i++) {
            _grantRole(VALIDATOR_ROLE, validators[i]);
        }
        _setSignatureThreshold(signatureThreshold_);
    }

    /**
     * @notice Execute borrow on an inventory pool
     * @dev Requires signatures from the threshold number of validators.
     * @param pool Address of the inventory pool contract
     * @param amount Amount to borrow from pool
     * @param recipient Address to receive the borrowed assets
     * @param expiry Timestamp after which the borrow is no longer valid
     * @param salt Unique value to prevent signature replay
     * @param signatures Array of validator signatures
     */
    function borrow(
        InventoryPool01 pool,
        uint amount,
        address recipient,
        uint expiry,
        bytes32 salt,
        bytes[] calldata signatures
    ) external {
        address borrower = _msgSender();

        bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(BORROW_TYPEHASH, pool, borrower, amount, recipient, expiry, block.chainid, salt)));
        _validateSignatures(digest, signatures);

        pool.borrow(amount, borrower, recipient, expiry, block.chainid);
    }

    /**
     * @notice Forgives a specified amount of debt for a borrower
     * @dev Requires signatures from the threshold number of validators. Can only be called by DEFAULT_ADMIN_ROLE
     * @param pool The inventory pool where the debt exists
     * @param amount The amount of debt to forgive
     * @param borrower The borrower whose debt should be forgiven
     * @param signatures Array of validator signatures
     */
    function forgiveDebt(
        InventoryPool01 pool,
        uint amount,
        address borrower,
        bytes[] calldata signatures
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(FORGIVE_DEBT_TYPEHASH, pool, amount, borrower)));
        _validateSignatures(digest, signatures);

        pool.forgiveDebt(amount, borrower);
    }

    /**
     * @notice Updates the base fee in the params contract
     * @dev Requires signatures from the threshold number of validators. Can only be called by DEFAULT_ADMIN_ROLE
     * @param paramsContract The params contract to update
     * @param newBaseFee The new base fee value to set
     * @param signatures Array of validator signatures
     */
    function updateBaseFee(OwnableParams01 paramsContract, uint newBaseFee, bytes[] calldata signatures) external onlyRole(DEFAULT_ADMIN_ROLE) {
        bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(UPDATE_BASE_FEE_TYPEHASH, paramsContract, newBaseFee)));
        _validateSignatures(digest, signatures);

        paramsContract.updateBaseFee(newBaseFee);
    }

    /**
     * @notice Updates the interest rate in the params contract
     * @dev Requires signatures from the threshold number of validators. Can only be called by DEFAULT_ADMIN_ROLE
     * @param paramsContract The params contract to update
     * @param newInterestRate The new interest rate value to set
     * @param signatures Array of validator signatures
     */
    function updateInterestRate(OwnableParams01 paramsContract, uint newInterestRate, bytes[] calldata signatures) external onlyRole(DEFAULT_ADMIN_ROLE) {
        bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(UPDATE_INTEREST_RATE_TYPEHASH, paramsContract, newInterestRate)));
        _validateSignatures(digest, signatures);

        paramsContract.updateInterestRate(newInterestRate);
    }

    /**
     * @notice Updates the penalty rate in the params contract
     * @dev Requires signatures from the threshold number of validators. Can only be called by DEFAULT_ADMIN_ROLE
     * @param paramsContract The params contract to update
     * @param newPenaltyRate The new penalty rate value to set
     * @param signatures Array of validator signatures
     */
    function updatePenaltyRate(OwnableParams01 paramsContract, uint newPenaltyRate, bytes[] calldata signatures) external onlyRole(DEFAULT_ADMIN_ROLE) {
        bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(UPDATE_PENALTY_RATE_TYPEHASH, paramsContract, newPenaltyRate)));
        _validateSignatures(digest, signatures);

        paramsContract.updatePenaltyRate(newPenaltyRate);
    }

    /**
     * @notice Updates the penalty period in the params contract
     * @dev Requires signatures from the threshold number of validators. Can only be called by DEFAULT_ADMIN_ROLE
     * @param paramsContract The params contract to update
     * @param newPenaltyPeriod The new penalty period value to set
     * @param signatures Array of validator signatures
     */
    function updatePenaltyPeriod(OwnableParams01 paramsContract, uint newPenaltyPeriod, bytes[] calldata signatures) external onlyRole(DEFAULT_ADMIN_ROLE) {
        bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(UPDATE_PENALTY_PERIOD_TYPEHASH, paramsContract, newPenaltyPeriod)));
        _validateSignatures(digest, signatures);

        paramsContract.updatePenaltyPeriod(newPenaltyPeriod);
    }

    /**
     * @notice Upgrades the params contract for an inventory pool
     * @dev Requires signatures from the threshold number of validators. Can only be called by DEFAULT_ADMIN_ROLE
     * @param pool The inventory pool to upgrade
     * @param paramsContract The new params contract to use
     * @param signatures Array of validator signatures
     */
    function upgradeParamsContract(InventoryPool01 pool, IInventoryPoolParams01 paramsContract, bytes[] calldata signatures) external onlyRole(DEFAULT_ADMIN_ROLE) {
        bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(UPGRADE_PARAMS_CONTRACT_TYPEHASH, pool, paramsContract)));
        _validateSignatures(digest, signatures);

        pool.upgradeParamsContract(paramsContract);
    }

    /**
     * @notice Overwrites core state variables in an inventory pool
     * @dev Requires signatures from the threshold number of validators. Can only be called by DEFAULT_ADMIN_ROLE
     * @param pool The inventory pool to overwrite core state
     * @param newStoredAccInterestFactor New value for stored accumulated interest factor
     * @param newLastAccumulatedInterestUpdate New value for last accumulated interest update timestamp
     * @param newScaledReceivables New value for scaled receivables
     */
    function overwriteCoreState(
        InventoryPool01 pool,
        uint newStoredAccInterestFactor,
        uint newLastAccumulatedInterestUpdate,
        uint newScaledReceivables,
        bytes[] calldata signatures
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(OVERWRITE_CORE_STATE_TYPEHASH, pool, newStoredAccInterestFactor, newLastAccumulatedInterestUpdate, newScaledReceivables)));
        _validateSignatures(digest, signatures);

        pool.overwriteCoreState(newStoredAccInterestFactor, newLastAccumulatedInterestUpdate, newScaledReceivables);
    }

    /**
     * @notice Transfers ownership of a contract owned by this contract
     * @dev Requires signatures from the threshold number of validators. Can only be called by DEFAULT_ADMIN_ROLE
     * @param ownedContract The contract to transfer ownership of
     * @param newOwner The address to transfer ownership to
     * @param signatures Array of validator signatures
     */
    function transferOwnership(Ownable ownedContract, address newOwner, bytes[] calldata signatures) external onlyRole(DEFAULT_ADMIN_ROLE) {
        bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(TRANSFER_OWNERSHIP_TYPEHASH, ownedContract, newOwner)));
        _validateSignatures(digest, signatures);

        ownedContract.transferOwnership(newOwner);
    }

    function grantRole(bytes32 role, address account) public virtual override(AccessControl, IAccessControl) onlyRole(getRoleAdmin(role)) {
        revert GrantRoleNotAllowed();
    }

    function revokeRole(bytes32 role, address account) public virtual override(AccessControl, IAccessControl) onlyRole(getRoleAdmin(role)) {
        revert RevokeRoleNotAllowed();
    }

    /**
     * @notice Adds a new validator to the system
     * @dev Requires signatures from the threshold number of validators. Can only be called by DEFAULT_ADMIN_ROLE
     * @param validator Address to be granted the VALIDATOR_ROLE
     * @param newSignatureThreshold New signature threshold to set after adding validator
     * @param signatures Array of validator signatures
     */
    function addValidator(address validator, uint16 newSignatureThreshold, bytes[] calldata signatures) external onlyRole(DEFAULT_ADMIN_ROLE) {
        bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(ADD_VALIDATOR_TYPEHASH, validator, newSignatureThreshold)));
        _validateSignatures(digest, signatures);

        _grantRole(VALIDATOR_ROLE, validator);
        validatorCount++;
        _setSignatureThreshold(newSignatureThreshold);
    }

    /**
     * @notice Removes a validator from the system
     * @dev Requires signatures from the threshold number of validators. Can only be called by DEFAULT_ADMIN_ROLE
     * @param validator Address to have VALIDATOR_ROLE revoked
     * @param newSignatureThreshold New signature threshold to set after removing validator
     * @param signatures Array of validator signatures
     */
    function removeValidator(address validator, uint16 newSignatureThreshold, bytes[] calldata signatures) external onlyRole(DEFAULT_ADMIN_ROLE) {
        bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(REMOVE_VALIDATOR_TYPEHASH, validator, newSignatureThreshold)));
        _validateSignatures(digest, signatures);

        _revokeRole(VALIDATOR_ROLE, validator);
        validatorCount--;
        _setSignatureThreshold(newSignatureThreshold);
    }

    /**
     * @notice Sets the signature threshold
     * @dev Requires signatures from the threshold number of validators. Can only be called by DEFAULT_ADMIN_ROLE
     * @param newSignatureThreshold The new signature threshold to set
     * @param signatures Array of validator signatures
     */
    function setSignatureThreshold(uint16 newSignatureThreshold, bytes[] calldata signatures) external onlyRole(DEFAULT_ADMIN_ROLE) {
        bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(SET_SIGNATURE_THRESHOLD_TYPEHASH, newSignatureThreshold)));
        _validateSignatures(digest, signatures);

        _setSignatureThreshold(newSignatureThreshold);
    }

    /**
     * @notice Returns the EIP-712 domain separator
     * @return The domain separator used in EIP-712 signatures
     */
    function domainSeparator() public view returns (bytes32) {
        return _domainSeparatorV4();
    }

    /**
     * @notice Returns the EIP-712 hash of a structured data
     * @param structHash The hash of the struct data to be signed
     * @return The EIP-712 typed data hash
     */
    function hashTypedData(bytes32 structHash) public view returns (bytes32) {
        return _hashTypedDataV4(structHash);
    }

    /**
     * @notice Internal function to validate multiple signatures
     * @dev Verifies that enough valid signatures from unique validators are provided
     * and that the signature hash hasn't been used before.
     * @param digest The EIP-712 message hash that was signed
     * @param signatures Array of validator signatures to verify
     */
    function _validateSignatures(bytes32 digest, bytes[] calldata signatures) internal {
        if (usedSigHashes[digest]) {
            revert SignatureUsed(digest);
        }
        usedSigHashes[digest] = true;

        uint validSignatures = 0;
        address[] memory signers = new address[](signatures.length);

        for (uint i = 0; i < signatures.length; i++) {
            address signer = ECDSA.recover(digest, signatures[i]);
            signers[i] = signer;

            if (_seenSigners[digest][signer]) {
                revert ValidatorNotUnique(signer);
            }

            _checkRole(VALIDATOR_ROLE, signer);

            _seenSigners[digest][signer] = true;
            validSignatures++;
        }

        if (validSignatures < signatureThreshold) {
            revert InvalidSignatureCount(validSignatures, signatureThreshold);
        }

        for (uint i = 0; i < signers.length; i++) {
            delete _seenSigners[digest][signers[i]];
        }
    }


    /**
     * @notice Internal function to update the signature threshold
     * @dev Ensures the new threshold is greater than half the validator count for security
     * @param newSignatureThreshold The new threshold value to set
     */
    function _setSignatureThreshold(uint16 newSignatureThreshold) internal {
        if (newSignatureThreshold <= validatorCount / 2) {
            revert SignatureThresholdTooLow(newSignatureThreshold, validatorCount);
        }
        signatureThreshold = newSignatureThreshold;

        emit SignatureThresholdUpdated(newSignatureThreshold);
    }
}
