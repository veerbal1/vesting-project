// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract VestToken is ERC20, Ownable {
    constructor(
        uint256 _initialSupply
    ) ERC20("VestToken", "VST") Ownable(msg.sender) {
        _mint(msg.sender, _initialSupply);
    }
}
