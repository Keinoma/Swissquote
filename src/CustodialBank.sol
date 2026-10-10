// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract CustodialBank {
    // L'adresse de Swissquote (la banque)
    address public owner;

    // Le registre : combien chaque client a chez Swissquote
    mapping(address => uint256) public balances;

    // L'état d'une demande : en attente, approuvée ou refusée
    enum Status { Pending, Approved, Rejected }

    // Le formulaire de retrait
    struct Request {
        address client;       // qui demande
        uint256 amount;       // combien
        address destination;  // où envoyer l'ETH
        Status status;        // où en est la demande
    }

    // Le classeur de toutes les demandes, numérotées 0, 1, 2...
    mapping(uint256 => Request) public requests;

    // Le numéro que prendra la prochaine demande
    uint256 public nextRequestId;

    event Deposited(address indexed client, uint256 amount);
    event WithdrawalRequested(uint256 indexed requestId, address indexed client, uint256 amount, address destination);
    event WithdrawalApproved(uint256 indexed requestId, address indexed client, uint256 amount, address destination);

    constructor() {
        owner = msg.sender;
    }

    function deposit() external payable {
        require(msg.value > 0, "Rien a deposer");
        balances[msg.sender] += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    // Alice remplit le formulaire. Aucun ETH ne bouge ici.
    function requestWithdrawal(uint256 amount, address destination) external {
        require(amount > 0, "Montant nul");
        require(balances[msg.sender] >= amount, "Solde insuffisant chez Swissquote");

        requests[nextRequestId] = Request({
            client: msg.sender,
            amount: amount,
            destination: destination,
            status: Status.Pending
        });

        emit WithdrawalRequested(nextRequestId, msg.sender, amount, destination);
        nextRequestId += 1;
    }

    // Swissquote examine la demande, puis envoie l'ETH
    function approveWithdrawal(uint256 requestId) external {
        require(msg.sender == owner, "Seul Swissquote peut approuver des request");

        Request storage r = requests[requestId];
        require(r.client != address(0), "Demande inconnue");
        require(r.status == Status.Pending, "Demande deja traitee");
        require(balances[r.client] >= r.amount, "Solde insuffisant");

        // On met le cahier a jour AVANT d'envoyer l'argent
        balances[r.client] -= r.amount;
        r.status = Status.Approved;

        // On envoie l'ETH a la destination
        (bool ok, ) = r.destination.call{value: r.amount}("");
        require(ok, "Envoi echoue");

        emit WithdrawalApproved(requestId, r.client, r.amount, r.destination);
    }
}