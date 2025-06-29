// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {VestToken} from "../src/VestToken.sol";
import {VestingWallet} from "../src/VestingWallet.sol";

contract VestingWalletTest is Test {
    VestToken public vstToken;
    VestingWallet public vestingWallet;

    address internal constant OWNER = address(0x1);
    address internal constant BENEFICIARY = address(0x2);
    address internal constant HACKER = address(0x3);

    // --- Vesting Parameters ---
    uint128 internal constant VESTING_AMOUNT = 100_000 * (10 ** 18); // 100k tokens

    // Using constants for better readability in tests
    uint64 internal constant ONE_YEAR = 365 days;
    uint64 internal constant FOUR_YEARS = 4 * ONE_YEAR;

    uint64 internal cliffDuration = ONE_YEAR;
    uint64 internal vestingDuration = FOUR_YEARS;

    function setUp() public {
        // 1. OWNER deploys the token contract
        vm.startPrank(OWNER);
        vstToken = new VestToken(1_000_000 * (10 ** 18)); // 1M total supply

        // 2. OWNER deploys the vesting wallet, linking it to the token
        vestingWallet = new VestingWallet(address(vstToken));
        vm.stopPrank();

        // --- Fund the Vesting Wallet ---

        // 3. OWNER transfers the total vesting amount to the vesting wallet contract
        // This is the "pool" of tokens the vesting contract will manage.
        vm.prank(OWNER);
        vstToken.transfer(address(vestingWallet), VESTING_AMOUNT);
    }

    // ===================================
    //      Section 1: Setup & State
    // ===================================
    function test_InitialState() public view {
        assertEq(vestingWallet.owner(), OWNER, "Owner should be set correctly");
        assertEq(
            address(vestingWallet.token()),
            address(vstToken),
            "Token address should be set correctly"
        );
        assertEq(
            vstToken.balanceOf(address(vestingWallet)),
            VESTING_AMOUNT,
            "Vesting wallet should have the correct balance"
        );
    }

    // =========================================
    //      Section 2: Access Control Tests
    // =========================================

    function test_OwnerCanAddVestingSchedule() public {
        vm.prank(OWNER);
        vestingWallet.addVestingSchedule(
            BENEFICIARY,
            VESTING_AMOUNT,
            vestingDuration,
            cliffDuration
        );
        assertEq(vestingWallet.beneficiaries(0), BENEFICIARY);

        VestingWallet.VestingSchedule memory schedule = vestingWallet
            .getVestingSchedule(BENEFICIARY);
        assertEq(
            schedule.beneficiary,
            BENEFICIARY,
            "Beneficiary should be set correctly"
        );
        assertEq(
            schedule.totalAmount,
            VESTING_AMOUNT,
            "Total amount should be set correctly"
        );
        assertEq(
            schedule.durationSeconds,
            vestingDuration,
            "Duration should be set correctly"
        );
        assertEq(
            schedule.cliffTimestamp,
            uint64(block.timestamp + cliffDuration),
            "Cliff timestamp should be set correctly"
        );
    }

    function test_Revert_NonOwnerCannotAddSchedule() public {
        vm.prank(HACKER);
        vm.expectRevert();
        vestingWallet.addVestingSchedule(
            HACKER,
            VESTING_AMOUNT,
            vestingDuration,
            cliffDuration
        );
    }
}
