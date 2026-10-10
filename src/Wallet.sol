// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract Wallet {
    address public owner;
    uint256 public nonce;

    address[3] public guardians;
    uint256 public constant THRESHOLD = 2;
    uint256 public constant DELAY = 1 days;

    address public pendingOwner;
    uint256 public approvalCount;
    uint256 public readyAt;
    uint256 public recoveryRound;
    mapping(uint256 => mapping(address => bool)) public approvedInRound;

    event RecoveryApproved(address indexed guardian, address indexed newOwner, uint256 approvals);
    event RecoveryCancelled();
    event RecoveryFinalized(address indexed newOwner);

    constructor(address _owner, address[3] memory _guardians) {
        owner = _owner;
        guardians = _guardians;
    }

    receive() external payable {}

    // ---- Utilisation normale (comme l'etape 4) ----
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

    // ---- Recuperation ----
    function isGuardian(address a) public view returns (bool) {
        for (uint256 i = 0; i < 3; i++) {
            if (guardians[i] == a) return true;
        }
        return false;
    }

    function approveRecovery(address newOwner) external {
        require(isGuardian(msg.sender), "Pas un gardien");
        require(newOwner != address(0), "Adresse nulle");
        if (pendingOwner != newOwner) {
            recoveryRound += 1;
            pendingOwner = newOwner;
            approvalCount = 0;
            readyAt = 0;
        }
        require(!approvedInRound[recoveryRound][msg.sender], "Deja approuve");
        approvedInRound[recoveryRound][msg.sender] = true;
        approvalCount += 1;
        if (approvalCount == THRESHOLD) {
            readyAt = block.timestamp + DELAY;
        }
        emit RecoveryApproved(msg.sender, newOwner, approvalCount);
    }

    function cancelRecovery() external {
        require(msg.sender == owner, "Reserve au proprietaire");
        _resetRecovery();
        emit RecoveryCancelled();
    }

    function finalizeRecovery() external {
        require(readyAt != 0, "Pas de recuperation prete");
        require(block.timestamp >= readyAt, "Delai pas ecoule");
        owner = pendingOwner;
        nonce += 1; // annule les anciennes signatures non utilisees
        emit RecoveryFinalized(owner);
        _resetRecovery();
    }

    function _resetRecovery() internal {
        pendingOwner = address(0);
        approvalCount = 0;
        readyAt = 0;
    }
}