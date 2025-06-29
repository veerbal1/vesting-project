// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract VestingWallet is Ownable {
    using SafeERC20 for IERC20;

    struct VestingSchedule {
        address beneficiary; // The person who will receive the tokens
        uint64 cliffTimestamp; // The timestamp when the cliff ends
        uint64 startTimestamp; // The timestamp when vesting begins
        uint64 durationSeconds; // The total duration of the vesting period
        uint128 totalAmount; // Total amount of tokens to be vested
        uint128 releasedAmount; // Amount of tokens already released
    }

    IERC20 public immutable token;

    mapping(address => VestingSchedule) private vestingSchedules;

    // An array of all beneficiary addresses, useful for off-chain UIs
    address[] public beneficiaries;

    event VestingScheduleAdded(
        address indexed beneficiary,
        uint256 totalAmount,
        uint64 startTimestamp,
        uint64 cliffTimestamp,
        uint64 durationSeconds
    );

    event TokensReleased(address indexed beneficiary, uint256 amount);

    error InvalidVestingParameters();
    error BeneficiaryAlreadyHasSchedule();
    error NoVestingScheduleFound();
    error NoTokensVestedYet();

    constructor(address _tokenAddress) Ownable(msg.sender) {
        token = IERC20(_tokenAddress);
    }

    /**
     * @notice Adds a new vesting schedule for a beneficiary.
     * @dev Only the owner can call this. The owner must ensure this contract holds enough
     * tokens to cover the schedules being added.
     * @param _beneficiary The address of the beneficiary.
     * @param _totalAmount The total amount of tokens to vest.
     * @param _durationSeconds The total duration of the vesting period in seconds.
     *   e.g., 4 years = 4 * 365 * 24 * 60 * 60
     * @param _cliffInSeconds The duration of the cliff in seconds from the start time.
     *   e.g., 1 year = 365 * 24 * 60 * 60. No tokens can be released before the cliff ends.
     */
    function addVestingSchedule(
        address _beneficiary,
        uint128 _totalAmount,
        uint64 _durationSeconds,
        uint64 _cliffInSeconds
    ) external onlyOwner {
        if (
            _totalAmount == 0 ||
            _durationSeconds == 0 ||
            _beneficiary == address(0)
        ) {
            revert InvalidVestingParameters();
        }

        if (vestingSchedules[_beneficiary].beneficiary != address(0)) {
            revert BeneficiaryAlreadyHasSchedule();
        }

        uint64 startTime = uint64(block.timestamp);

        vestingSchedules[_beneficiary] = VestingSchedule({
            beneficiary: _beneficiary,
            cliffTimestamp: uint64(startTime + _cliffInSeconds),
            startTimestamp: uint64(startTime),
            durationSeconds: _durationSeconds,
            totalAmount: _totalAmount,
            releasedAmount: 0
        });

        beneficiaries.push(_beneficiary);
        emit VestingScheduleAdded(
            _beneficiary,
            _totalAmount,
            startTime,
            startTime + _cliffInSeconds,
            _durationSeconds
        );
    }

    /**
     * @notice Allows a beneficiary to release their vested tokens.
     * @dev Any beneficiary can call this at any time to claim the portion of tokens
     * that have vested according to their schedule.
     */
    function release() external {
        VestingSchedule storage schedule = vestingSchedules[msg.sender];
        if (schedule.beneficiary != msg.sender) {
            revert NoVestingScheduleFound();
        }

        uint256 releasable = releasableAmount(msg.sender);
        if (releasable == 0) {
            revert NoTokensVestedYet();
        }

        schedule.releasedAmount += uint128(releasable);

        emit TokensReleased(msg.sender, releasable);

        token.safeTransfer(msg.sender, releasable);
    }

    /**
     * @notice Calculates the amount of tokens that a beneficiary can release at the current time.
     * @param _beneficiary The address of the beneficiary.
     * @return The amount of tokens that can be claimed now.
     */
    function releasableAmount(
        address _beneficiary
    ) public view returns (uint256) {
        VestingSchedule memory schedule = vestingSchedules[_beneficiary];
        if (schedule.beneficiary == address(0)) return 0;

        uint256 totalVested = _getVestedAmount(schedule);
        return totalVested - schedule.releasedAmount;
    }

    /**
     * @notice Returns the full vesting schedule for a given beneficiary.
     * @param _beneficiary The address of the beneficiary to query.
     */
    function getVestingSchedule(
        address _beneficiary
    ) external view returns (VestingSchedule memory) {
        return vestingSchedules[_beneficiary];
    }

    /**
     * @dev The core logic for calculating the total vested amount for a schedule at the current time.
     * This follows a linear vesting curve after the cliff.
     * @param _schedule The vesting schedule to calculate for.
     * @return The total amount of tokens that should have vested by `block.timestamp`.
     */

    function _getVestedAmount(
        VestingSchedule memory _schedule
    ) private view returns (uint256) {
        uint64 currentTime = uint64(block.timestamp);

        // Case 1: Before the cliff. No tokens have vested.
        if (currentTime < _schedule.cliffTimestamp) {
            return 0;
        }

        // Case 2: After the full vesting period has ended. All tokens have vested.
        uint64 vestingEndDate = _schedule.startTimestamp +
            _schedule.durationSeconds;
        if (currentTime >= vestingEndDate) {
            return _schedule.totalAmount;
        }

        // Case 3: During the linear vesting period (after cliff, before end).
        uint256 timeElapsed = currentTime - _schedule.startTimestamp;
        // We use uint256 for the multiplication to avoid overflow before the division.
        // This calculates the vested amount proportionally to the time elapsed.
        return
            (uint256(_schedule.totalAmount) * timeElapsed) /
            _schedule.durationSeconds;
    }
}
