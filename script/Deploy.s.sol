// script/Deploy.s.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {VestingWallet} from "../src/VestingWallet.sol";
import {VestToken} from "../src/VestToken.sol";

contract Deploy is Script {
    // These values will be configured for the deployment.
    uint256 public constant INITIAL_SUPPLY = 1_000_000 * (10 ** 18);
    uint256 public constant RATE = 20_000; // 1 ETH = 20,000 AWSM

    function run() external returns (address, address) {
        vm.startBroadcast();

        // 1. Deploy the token. All tokens are minted to the deployer.
        VestToken token = new VestToken(INITIAL_SUPPLY);

        // 2. Deploy the VestingWallet contract, linking it to the token.
        VestingWallet vestingWallet = new VestingWallet(address(token));

        vm.stopBroadcast();

        console.log("AwesomeToken deployed at:", address(token));
        console.log("Crowdsale deployed at:", address(vestingWallet));

        return (address(token), address(vestingWallet));
    }
}
