
pragma solidity ^0.8.4;

interface ICorePool {
    event Stake(
        uint256 amount,
        uint256 lockUnits,
        uint256 depositId
    );
    event Unstake(
        uint256 amount,
        uint256 depositId,
        uint256 rewardAmount
    );
    event Claim(
        uint256 indexed depositId,
        uint256 rewardAmount
    );

    struct Deposit {
        uint256 id;
        uint256 amount;
        uint256 index;
        uint256 extraWeightedAmount;
        uint256 depositTime;
        uint256 lockUnits;
    }

    function stake(uint256 amount, uint256 lockUnits) external;

    function unstake(uint256 depositId) external;

    function claim(uint256 depositId) external;

    function pendingReward(address staker, uint256 depositId)
        external
        view
        returns (uint256 rewardAmount);

    function getDeposit(address staker, uint256 depositId)
        external
        view
        returns (Deposit memory);
}
