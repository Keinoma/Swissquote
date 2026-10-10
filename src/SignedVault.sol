// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract SignedVault {
    address public immutable owner;
    uint256 public nonce;

    constructor(address _owner) {
        owner = _owner;
    }

    receive() external payable {}

    function getHash(uint256 amount, address destination) public view returns (bytes32) {
        return keccak256(abi.encode(address(this), block.chainid, nonce, amount, destination));
    }

    function withdrawSigned(uint256 amount, address payable destination, bytes calldata signature) external {
        bytes32 digest = MessageHashUtils.toEthSignedMessageHash(getHash(amount, destination));
        require(ECDSA.recover(digest, signature) == owner, "Signature invalide");
        nonce += 1;
        (bool ok, ) = destination.call{value: amount}("");
        require(ok, "Envoi echoue");
    }
}