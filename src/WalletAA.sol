// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Account} from "@openzeppelin/contracts/account/Account.sol";
import {SignerECDSA} from "@openzeppelin/contracts/utils/cryptography/signers/SignerECDSA.sol";

// Compte ERC-4337 (bibliotheque OpenZeppelin) + recuperation par gardiens.
contract WalletAA is Account, SignerECDSA {
    address[3] public guardians;
    uint256 public constant THRESHOLD = 2;
    uint256 public constant DELAY = 12 seconds; // DEMO. En production : 1 days

    address public pendingOwner;
    uint256 public approvalCount;
    uint256 public readyAt;
    uint256 public recoveryRound;
    mapping(uint256 => mapping(address => bool)) public approvedInRound;

    event RecoveryApproved(address indexed guardian, address indexed newOwner, uint256 approvals);
    event RecoveryCancelled();
    event RecoveryFinalized(address indexed newOwner);

    constructor(address _owner, address[3] memory _guardians) SignerECDSA(_owner) {
        guardians = _guardians;
    }

    // Le proprietaire = le signataire du compte
    function owner() public view returns (address) {
        return signer();
    }

    // Appelee par l'EntryPoint apres validation de la signature du proprietaire
    function execute(address to, uint256 value, bytes calldata data) external onlyEntryPointOrSelf {
        (bool ok, ) = to.call{value: value}(data);
        require(ok, "Appel echoue");
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

    // Le proprietaire annule en signant une UserOperation
    function cancelRecovery() external onlyEntryPointOrSelf {
        _resetRecovery();
        emit RecoveryCancelled();
    }

    function finalizeRecovery() external {
        require(readyAt != 0, "Pas de recuperation prete");
        require(block.timestamp >= readyAt, "Delai pas ecoule");
        address newOwner = pendingOwner;
        _setSigner(newOwner); // l'ancienne cle perd tous ses droits
        emit RecoveryFinalized(newOwner);
        _resetRecovery();
    }

    function _resetRecovery() internal {
        pendingOwner = address(0);
        approvalCount = 0;
        readyAt = 0;
    }
}