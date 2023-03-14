
pragma solidity ^0.8.4;
import "./ICorePool.sol";

interface IRewardPool is ICorePool {

    struct LockedReward {
        uint256 id;
        uint256 amount;
        uint256 remaingAmount;
        uint256 index;
        uint256 lockTime;
        uint256 lastWithdrawTime;
        uint256 withdrawCount;
        address depositPool;
        address depositToken;
        uint256 depositId;
    }

    function lockReward(
        address staker,
        uint256 amount,
        address depositPool,
        address depositToken,
        uint256 depositId
    ) external;

    function withdraw(uint256 rewardId) external;

    function getLockedRewards(address staker)
        external
        view
        returns (LockedReward[] memory);
}
