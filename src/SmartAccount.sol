// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract SmartAccount {
    address public owner;
    uint256 public nonce;

    constructor(address _owner) {
        owner = _owner;
    }

    receive() external payable {}

    function getHash(address to, uint256 value, bytes calldata data) public view returns (bytes32) {
        return keccak256(abi.encode(address(this), block.chainid, nonce, to, value, data));
    }

    function execute(address to, uint256 value, bytes calldata data, bytes calldata signature) external {
        bytes32 digest = MessageHashUtils.toEthSignedMessageHash(getHash(to, value, data));
        require(ECDSA.recover(digest, signature) == owner, "Signature invalide");
        nonce += 1;
        (bool ok, ) = to.call{value: value}(data);
        require(ok, "Appel echoue");
    }

    function setOwner(address newOwner) external {
        require(msg.sender == address(this), "Seulement via le compte lui-meme");
        owner = newOwner;
    }
}