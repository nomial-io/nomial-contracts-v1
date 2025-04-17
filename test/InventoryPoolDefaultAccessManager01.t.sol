// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {InventoryPoolDefaultAccessManager01} from "../src/owners/InventoryPoolDefaultAccessManager01.sol";
import {InventoryPool01} from "../src/InventoryPool01.sol";
import {InventoryPoolDefaultAccessManagerDeployer01} from "../src/deployment/InventoryPoolDefaultAccessManagerDeployer01.sol";
import {InventoryPoolDeployer01} from "../src/deployment/InventoryPoolDeployer01.sol";
import {OwnableParamsDeployer01} from "../src/deployment/OwnableParamsDeployer01.sol";
import {UtilizationBasedRateParamsDeployer01} from "../src/deployment/UtilizationBasedRateParamsDeployer01.sol";
import {NomialDeployer01} from "../src/deployment/NomialDeployer01.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "./Helper.sol";

contract InventoryPoolDefaultAccessManager01Test is Test, Helper {    
    address public constant admin = address(1);
    address public constant validator = address(2);
    address public constant borrower = address(3);
    address public constant recipient = address(4);
    bytes32 public constant salt1 = bytes32(uint256(1));
    bytes32 public constant salt2 = bytes32(uint256(2));

    uint256 public constant validatorPrivateKey = 0x2;
    bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");

    address[] public validators = [address(7), address(8), address(9)];
    uint16 public signatureThreshold = 2;

    InventoryPoolDeployer01 public poolDeployer;
    OwnableParamsDeployer01 public ownableParamsDeployer;
    UtilizationBasedRateParamsDeployer01 public utilizationBasedParamsDeployer;
    NomialDeployer01 public nomialDeployer;
    InventoryPoolDefaultAccessManagerDeployer01 public accessManagerDeployer;
    InventoryPool01 public wethInventoryPool;
    address public accessManagerAddr;
    InventoryPoolDefaultAccessManager01 public accessManager;

    function setUp() public {
        setupAll();

        poolDeployer = new InventoryPoolDeployer01();
        ownableParamsDeployer = new OwnableParamsDeployer01();
        utilizationBasedParamsDeployer = new UtilizationBasedRateParamsDeployer01();
        accessManagerDeployer = new InventoryPoolDefaultAccessManagerDeployer01();
        nomialDeployer = new NomialDeployer01(
            address(poolDeployer),
            address(utilizationBasedParamsDeployer),
            address(accessManagerDeployer)
        );

        // Deploy WETH pool
        // Deploy WETH pool
        vm.startPrank(WETH_WHALE);
        WETH_ERC20.approve(address(poolDeployer), MAX_UINT);
        (address payable wethPoolAddress,,address payable wethPoolAccessManager_) = nomialDeployer.deploy(
            salt2,
            abi.encode(admin, validators, signatureThreshold),
            abi.encode(defaultBaseFee, defaultBaseRate, defaultRate1, defaultRate2, defaultOptimalUtilizationRate, defaultPenaltyRate, defaultPenaltyPeriod),
            abi.encode(IERC20(WETH), "nomialWETH", "nmlWETH", 1 * 10**14),
            WETH_WHALE
        );
        wethInventoryPool = InventoryPool01(wethPoolAddress);
        accessManagerAddr = wethPoolAccessManager_;
        accessManager = InventoryPoolDefaultAccessManager01(accessManagerAddr);
        vm.stopPrank();
    }

    function testInventoryPoolDefaultAccessManager01_constructor() public {
        assertTrue(accessManagerAddr.code.length > 0, "Access manager should be deployed");

        assertTrue(accessManager.hasRole(accessManager.DEFAULT_ADMIN_ROLE(), admin), "Admin should have default role");

        for (uint i = 0; i < validators.length; i++) {
            assertTrue(accessManager.hasRole(accessManager.VALIDATOR_ROLE(), validators[i]), "Validator should have validator role");
        }

        assertTrue(accessManager.signatureThreshold() == signatureThreshold, "Signature threshold should be set");
    }
} 
