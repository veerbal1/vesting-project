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

    // =========================================
    //      Section 3: Time-Travel & Release Logic
    // =========================================
    // A modifier to set up a standard vesting schedule for the beneficiary
    modifier withVestingSchedule() {
        vm.prank(OWNER);
        vestingWallet.addVestingSchedule(
            BENEFICIARY,
            VESTING_AMOUNT,
            vestingDuration,
            cliffDuration
        );
        _;
    }

    function test_CannotReleaseBeforeCliff() public withVestingSchedule {
        // We are at time 0. The cliff is at 1 year.
        // Let's warp to just before the cliff ends.
        uint64 timeBeforeCliff = uint64(
            block.timestamp + cliffDuration - 1 days
        );
        vm.warp(timeBeforeCliff);

        // Check that no tokens are releasable
        assertEq(
            vestingWallet.releasableAmount(BENEFICIARY),
            0,
            "No tokens should be releasable before the cliff"
        );

        // Check that calling release() reverts
        vm.prank(BENEFICIARY);
        vm.expectRevert(VestingWallet.NoTokensVestedYet.selector);
        vestingWallet.release();
    }

    function test_CanReleaseAtCliff() public withVestingSchedule {
        // Warp time to the exact moment the cliff ends (1 year)
        uint64 cliffTimestamp = uint64(block.timestamp + cliffDuration);
        vm.warp(cliffTimestamp);

        // The vested amount at the 1-year cliff of a 4-year vest should be 25%
        uint256 expectedAmount = VESTING_AMOUNT / 4;
        assertEq(
            vestingWallet.releasableAmount(BENEFICIARY),
            expectedAmount,
            "Incorrect amount at cliff"
        );

        // Beneficiary releases the tokens
        vm.prank(BENEFICIARY);
        vestingWallet.release();

        // Check beneficiary's token balance
        assertEq(
            vstToken.balanceOf(BENEFICIARY),
            expectedAmount,
            "Beneficiary balance is wrong after cliff release"
        );

        // Check that the releasable amount is now 0 (or very close to it due to block timestamp progression)
        assertEq(
            vestingWallet.releasableAmount(BENEFICIARY),
            0,
            "Releasable should be ~0 after release"
        );
    }

    function test_CanReleaseMidVesting() public withVestingSchedule {
        uint64 twoYears = uint64(block.timestamp + 2 * ONE_YEAR);
        vm.warp(twoYears);

        // The vested amount should be 50%
        uint256 expectedAmount = VESTING_AMOUNT / 2;
        assertEq(
            vestingWallet.releasableAmount(BENEFICIARY),
            expectedAmount,
            "Incorrect amount at 2 years"
        );

        // Release and check balance
        vm.prank(BENEFICIARY);
        vestingWallet.release();

        // Check beneficiary's token balance
        assertEq(
            vstToken.balanceOf(BENEFICIARY),
            expectedAmount,
            "Beneficiary balance is wrong after mid-vesting release"
        );
    }

    function test_CanReleaseAfterVestingEnds() public withVestingSchedule {
        // Warp time to 5 years, well after the 4-year vesting period is over
        uint64 fiveYears = uint64(block.timestamp + 5 * ONE_YEAR);
        vm.warp(fiveYears);

        // All tokens should be releasable
        assertEq(
            vestingWallet.releasableAmount(BENEFICIARY),
            VESTING_AMOUNT,
            "Should be able to release all tokens after vesting"
        );

        // Release and check balance
        vm.prank(BENEFICIARY);
        vestingWallet.release();

        // Check beneficiary's token balance
        assertEq(
            vstToken.balanceOf(BENEFICIARY),
            VESTING_AMOUNT,
            "Beneficiary balance is wrong after vesting ends"
        );

        assertEq(
            vestingWallet.releasableAmount(BENEFICIARY),
            0,
            "Releasable should be 0 after full release"
        );
    }

    function test_MultipleReleases() public withVestingSchedule {
        // 1. Release at cliff (1 year)
        vm.warp(block.timestamp + ONE_YEAR);
        vm.prank(BENEFICIARY);
        vestingWallet.release();
        uint256 cliffAmount = VESTING_AMOUNT / 4;
        assertEq(vstToken.balanceOf(BENEFICIARY), cliffAmount);

        // 2. Warp another year (total 2 years elapsed) and release again
        vm.warp(block.timestamp + ONE_YEAR);
        vm.prank(BENEFICIARY);
        vestingWallet.release();
        uint256 twoYearAmount = VESTING_AMOUNT / 2;
        assertEq(
            vstToken.balanceOf(BENEFICIARY),
            twoYearAmount,
            "Balance at 2 years is wrong"
        );

        // Check how much was released in the second transaction
        uint256 secondReleaseAmount = twoYearAmount - cliffAmount;
        // You could also check the event for this amount using vm.expectEmit
        assertEq(
            secondReleaseAmount,
            cliffAmount,
            "Second release should be another 25%"
        );
    }

    // =========================================
    //      Section 4: Fuzz Testing
    // =========================================
    function test_Fuzz_ReleasableAmountIsAlwaysCorrect(
        uint64 timeToWarp
    ) public withVestingSchedule {
        // We only want to test realistic times.
        // Let's bound the time warp from 0 to 5 years past the start.
        vm.assume(timeToWarp > 0 && timeToWarp < 5 * ONE_YEAR);

        VestingWallet.VestingSchedule memory schedule = vestingWallet
            .getVestingSchedule(BENEFICIARY);

        // Warp to the random future time
        uint64 futureTime = schedule.startTimestamp + timeToWarp;
        vm.warp(futureTime);

        // Manually calculate what the vested amount should be, using the same logic as the contract
        uint256 expectedVestedAmount;
        if (futureTime < schedule.cliffTimestamp) {
            expectedVestedAmount = 0;
        } else if (
            futureTime >= schedule.startTimestamp + schedule.durationSeconds
        ) {
            expectedVestedAmount = schedule.totalAmount;
        } else {
            uint256 timeElapsed = futureTime - schedule.startTimestamp;
            expectedVestedAmount =
                (uint256(schedule.totalAmount) * timeElapsed) /
                schedule.durationSeconds;
        }

        assertEq(
            vestingWallet.releasableAmount(BENEFICIARY),
            expectedVestedAmount,
            "Fuzz test failed: releasable amount mismatch"
        );
    }
}
