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
    bytes32 public constant BORROWER_ROLE = keccak256("BORROWER_ROLE");

    InventoryPoolDeployer01 public poolDeployer;
    OwnableParamsDeployer01 public ownableParamsDeployer;
    UtilizationBasedRateParamsDeployer01 public utilizationBasedParamsDeployer;
    NomialDeployer01 public nomialDeployer;
    InventoryPoolDefaultAccessManagerDeployer01 public accessManagerDeployer;
    InventoryPool01 public wethInventoryPool;
    address public accessManagerAddr;

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
        vm.startPrank(WETH_WHALE);
        WETH_ERC20.approve(address(poolDeployer), MAX_UINT);
        (address payable wethPoolAddress,,address payable accessManagerAddr_) = nomialDeployer.deploy(
            salt1,
            IERC20(WETH),
            "nomialWETH",
            "nmlWETH",
            1 * 10**14,
            admin,
            abi.encode(defaultBaseFee, defaultBaseRate, defaultRate1, defaultRate2, defaultOptimalUtilizationRate, defaultPenaltyRate, defaultPenaltyPeriod),
            WETH_WHALE
        );
        wethInventoryPool = InventoryPool01(wethPoolAddress);
        accessManagerAddr = accessManagerAddr_;
        vm.stopPrank();

        // Setup roles
        vm.startPrank(admin);
        AccessControl(accessManagerAddr).grantRole(VALIDATOR_ROLE, admin);
        AccessControl(accessManagerAddr).grantRole(BORROWER_ROLE, admin);
        AccessControl(accessManagerAddr).grantRole(VALIDATOR_ROLE, validator);
        AccessControl(accessManagerAddr).grantRole(BORROWER_ROLE, borrower);
        vm.stopPrank();

        // Fund pool with WETH
        vm.startPrank(WETH_WHALE);
        WETH_ERC20.approve(address(wethInventoryPool), MAX_UINT);
        wethInventoryPool.deposit(1000 * 10**18, WETH_WHALE);
        vm.stopPrank();
    }

    function testBorrow_success() public {
        uint256 amount = 10 * 10**18;
        uint256 expiry = block.timestamp + 1 days;

        // Generate EIP-712 signature from validator
        InventoryPoolDefaultAccessManager01 accessManager = InventoryPoolDefaultAccessManager01(accessManagerAddr);
        bytes32 domainSeparator = InventoryPoolDefaultAccessManager01(accessManagerAddr).domainSeparator();
        bytes32 BORROW_TYPEHASH = keccak256(
            "Borrow(address pool,address borrower,uint256 amount,address recipient,uint256 expiry,uint256 chainId,bytes32 salt)"
        );
        
        bytes32 structHash = keccak256(
            abi.encode(
                BORROW_TYPEHASH,
                address(wethInventoryPool),
                borrower,
                amount,
                recipient,
                expiry,
                block.chainid,
                salt2
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(validatorPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Record initial balances
        uint256 recipientBalanceBefore = WETH_ERC20.balanceOf(recipient);

        // Execute borrow
        vm.prank(borrower);
        accessManager.borrow(
            address(wethInventoryPool),
            amount,
            recipient,
            expiry,
            salt2,
            signature
        );

        // Verify recipient received tokens
        assertEq(
            WETH_ERC20.balanceOf(recipient),
            recipientBalanceBefore + amount,
            "Recipient should receive borrowed tokens"
        );
    }
} 