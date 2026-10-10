// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract SelfVault {
    address public immutable owner;

    constructor(address _owner) {
        owner = _owner;
    }

    receive() external payable {}

    function withdraw(uint256 amount, address payable destination) external {
        require(msg.sender == owner, "Reserve au proprietaire");
        (bool ok, ) = destination.call{value: amount}("");
        require(ok, "Envoi echoue");
    }
}