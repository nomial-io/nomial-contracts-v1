// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

library DeployerLib {
    function addressFromBytecode(
        address deployer,
        bytes32 salt,
        bytes memory bytecode
    ) internal pure returns (address) {
        bytes32 bytecodeHash = keccak256(bytecode);
        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), deployer, salt, bytecodeHash));
        return address(uint160(uint256(hash)));
    }
} 