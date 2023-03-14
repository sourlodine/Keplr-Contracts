
pragma solidity ^0.8.4;

interface IPoolFactory {
    struct DashboardView {
        uint256 totalPendingRewards;
        uint256 totalPendingRewardsValue;
        uint256 keplBalance;
        uint256 keplBalanceValue;
        uint256 totalStakedValue;
        uint256 totalDistributed;
        uint256 totalDistributedValue;
    }

    struct DepoistPoolView {
        address pool;
        uint256 weight;
        address depositToken;
        uint256 tvl;
        uint256 apy;
        uint256 pendingRewards;
        uint256 mydepositAmount;
        uint256 maxLockUnits;
        uint256 lockUnitDuration;
        uint256 lockUnitMultiplier;
    }

    struct MyDepositView {
        address depositPool;
        uint256 depositId;
        address depositToken;
        uint256 apy;
        uint256 lockUnits;
        uint256 stakingAmount;
        uint256 pendingRewards;
    }

    struct LockedRewardView {
        uint256 lockedRewardId;
        address depositPool;
        address depositToken;
        uint256 lockedAmount;
        uint256 pendingRewards;
        uint256 apy;
        uint256 nextUnlockTime;
        uint256 withdrawableAmount;
    }

    function getDashboardView() external view returns (DashboardView memory);

    function getDepositPoolViews(address staker)
        external
        view
        returns (DepoistPoolView[] memory);

    function getMyDepositView(address staker)
        external
        view
        returns (MyDepositView[] memory views);

    function getLockedRewardView(address staker)
        external
        view
        returns (LockedRewardView[] memory);

    function getRewardsPerBlock(address pool) external view returns (uint256);
}
