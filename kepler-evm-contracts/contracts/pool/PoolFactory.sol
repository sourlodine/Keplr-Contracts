
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../libraries/SafeDecimalMath.sol";
import "../tokens/IToken.sol";
import "../oracle/IOracle.sol";
import "./RewardPool.sol";
import "./DepositPool.sol";
import "./IPoolFactory.sol";

contract PoolFactory is OwnableUpgradeable, IPoolFactory {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeDecimalMath for uint256;

    mapping(address => uint256) private _poolWeights;
    EnumerableSet.AddressSet private _depositPools;
    uint256 public totalWeight;
    uint256 public rewardsPerBlock;
    uint256 public blocksPerYear;
    address private _rewardPool;
    address private _oracle;
    address public rewardToken;

    function initialize() public initializer {
        __Ownable_init();
    }

    function queryPoolWeights()
        public
        view
        returns (address[] memory pools, uint256[] memory weights)
    {
        pools = new address[](_depositPools.length());
        weights = new uint256[](pools.length);
        for (uint256 i; i < pools.length; i++) {
            address pool = _depositPools.at(i);
            pools[i] = pool;
            weights[i] = _poolWeights[pool];
        }
    }

    function postInitialize(
        address rewardPool_,
        address oracle_,
        address rewardToken_,
        uint256 blocksPerYear_,
        uint256 rewardsPerBlock_
    ) public onlyOwner {
        _rewardPool = rewardPool_;
        _oracle = oracle_;
        rewardToken = rewardToken_;
        blocksPerYear = blocksPerYear_;
        rewardsPerBlock = rewardsPerBlock_;
    }

    function getDepositPools()
        external
        view
        returns (address[] memory depositPools)
    {
        depositPools = new address[](_depositPools.length());
        for (uint256 i; i < depositPools.length; i++) {
            depositPools[i] = _depositPools.at(i);
        }
    }

    function updatePoolWeights(address[] memory pools, uint256[] memory weights)
        external
        onlyOwner
    {
        require(pools.length == weights.length, "INVALID_PARAMETERS");
        for (uint256 i; i < pools.length; i++) {
            (address pool, uint256 weight) = (pools[i], weights[i]);
            _depositPools.add(pool);
            uint256 oldWeight = _poolWeights[pool];
            _poolWeights[pool] = weight;
            totalWeight = totalWeight + weight - oldWeight;
        }
    }

    function getRewardsPerBlock(address pool)
        public
        view
        override
        returns (uint256)
    {
        return (rewardsPerBlock * _poolWeights[pool]) / totalWeight;
    }

    function getMyDepositView(address staker)
        external
        view
        override
        returns (MyDepositView[] memory views)
    {
        uint256 depositCount;
        for (uint256 i = 0; i < _depositPools.length(); i++) {
            depositCount += DepositPool(_depositPools.at(i))
                .getUserDepoistCount(staker);
        }
        views = new MyDepositView[](depositCount);
        uint256 viewsIndex;
        for (uint256 i = 0; i < _depositPools.length(); i++) {
            address pool = _depositPools.at(i);
            DepositPool depositPool = DepositPool(pool);
            uint256 depositTokenPrice = IOracle(_oracle).queryPrice(
                depositPool.depositToken()
            );

            uint256 tvl = depositPool.depositAmount().multiplyDecimal(
                depositTokenPrice
            );
            DepositPool.Deposit[] memory deposits = depositPool.getUserDepoists(
                staker
            );
            for (uint256 j; j < deposits.length; j++) {
                views[viewsIndex++] = composeMyDepositView(
                    staker,
                    depositPool,
                    deposits[j],
                    tvl
                );
            }
        }
    }

    function composeMyDepositView(
        address staker,
        DepositPool depositPool,
        DepositPool.Deposit memory deposit,
        uint256 tvl
    ) private view returns (MyDepositView memory) {
        uint256 depositId = deposit.id;
        uint256 basicAPY = calculateBasicAPY(address(depositPool), tvl);
        uint256 extraApy = (basicAPY * deposit.extraWeightedAmount) /
            deposit.amount;
        return
            MyDepositView({
                depositPool: address(depositPool),
                depositId: depositId,
                depositToken: depositPool.depositToken(),
                apy: basicAPY + extraApy,
                lockUnits: deposit.lockUnits,
                stakingAmount: deposit.amount,
                pendingRewards: depositPool.pendingReward(staker, depositId)
            });
    }

    function _makeDepoistPoolView(address staker, address pool)
        private
        view
        returns (DepoistPoolView memory)
    {
        DepositPool depositPool = DepositPool(pool);
        uint256 depositAmount = depositPool.depositAmount();
        uint256 depositTokenPrice = IOracle(_oracle).queryPrice(
            depositPool.depositToken()
        );
        uint256 tvl = depositAmount.multiplyDecimal(depositTokenPrice);

        uint256 totalRewards = depositPool.totalRewards();
        uint256 claimedRewards = depositPool.claimedRewards();
        return
            DepoistPoolView({
                pool: pool,
                weight: _poolWeights[pool],
                depositToken: depositPool.depositToken(),
                tvl: tvl,
                apy: calculateBasicAPY(pool, tvl),
                pendingRewards: totalRewards - claimedRewards,
                mydepositAmount: depositPool.userTotalDeposits(staker),
                maxLockUnits: depositPool.maxLockUnits(),
                lockUnitDuration: depositPool.lockUnitDuration(),
                lockUnitMultiplier: depositPool.lockUnitMultiplier()
            });
    }

    function getLockedRewardView(address staker)
        public
        view
        override
        returns (LockedRewardView[] memory views)
    {
        RewardPool rewardPool = RewardPool(_rewardPool);
        RewardPool.LockedReward[] memory lockedRewards = rewardPool
            .getLockedRewards(staker);

        uint256 depositAmount = rewardPool.depositAmount();
        uint256 depositTokenPrice = IOracle(_oracle).queryPrice(rewardToken);
        uint256 tvl = depositAmount.multiplyDecimal(depositTokenPrice);
        uint256 basicAPY = calculateBasicAPY(_rewardPool, tvl);
        uint256 extraAPY = rewardPool.rewardMultiplier().multiplyDecimal(
            basicAPY
        );
        uint256 withdrawCount = rewardPool.WITHDRAW_COUNT();
        views = new LockedRewardView[](lockedRewards.length);
        uint256 withdrawInterval = rewardPool.withdrawInterval();
        for (uint256 i; i < lockedRewards.length; i++) {
            RewardPool.LockedReward memory lockedReward = lockedRewards[i];
            uint256 passedUnits = (block.timestamp - lockedReward.lockTime) /
                withdrawInterval;

            uint256 nextUnlockTime = lockedReward.lockTime +
                (passedUnits + 1) *
                withdrawInterval;

            views[i] = LockedRewardView({
                lockedRewardId: lockedReward.id,
                depositPool: lockedReward.depositPool,
                depositToken: lockedReward.depositToken,
                lockedAmount: lockedReward.amount,
                pendingRewards: lockedReward.remaingAmount,
                apy: basicAPY + extraAPY,
                nextUnlockTime: nextUnlockTime,
                withdrawableAmount: lockedReward.amount /
                    withdrawCount +
                    rewardPool.getWithdrawReward(lockedReward)
            });
        }
    }

    function calculateBasicAPY(address pool, uint256 tvl)
        private
        view
        returns (uint256)
    {
        uint256 rewardTokenPrice = IOracle(_oracle).queryPrice(rewardToken);
        uint256 oneYearRewardValue = rewardTokenPrice.multiplyDecimal(
            getRewardsPerBlock(pool) * blocksPerYear
        );
        return (100 * oneYearRewardValue).multiplyDecimal(tvl);
    }

    function getDashboardView()
        public
        view
        override
        returns (DashboardView memory)
    {
        RewardPool rewardPool = RewardPool(_rewardPool);
        IOracle oracle = IOracle(_oracle);
        address keplToken = rewardPool.rewardToken();
        uint256 keplPrice = oracle.queryPrice(keplToken);

        uint256 lockedRewardAmount = rewardPool.lockedRewardAmount();

        uint256 keplBalance = IToken(keplToken).balanceOf(msg.sender);

        uint256 totalStakedValue;
        uint256 totalDistributed;

        for (uint256 i = 0; i < _depositPools.length(); i++) {
            DepositPool pool = DepositPool(_depositPools.at(i));
            address depositToken = pool.depositToken();
            uint256 depositAmount = pool.depositAmount();
            totalStakedValue += depositAmount.multiplyDecimal(
                oracle.queryPrice(depositToken)
            );

            uint256 totalRewards = pool.totalRewards();
            totalDistributed += totalRewards;
        }

        return
            DashboardView({
                totalPendingRewards: lockedRewardAmount,
                totalPendingRewardsValue: lockedRewardAmount.multiplyDecimal(
                    keplPrice
                ),
                keplBalance: keplBalance,
                keplBalanceValue: keplBalance.multiplyDecimal(keplPrice),
                totalStakedValue: totalStakedValue,
                totalDistributed: totalDistributed,
                totalDistributedValue: totalDistributed.multiplyDecimal(
                    keplPrice
                )
            });
    }

    function getDepositPoolViews(address staker)
        public
        view
        override
        returns (DepoistPoolView[] memory)
    {
        DepoistPoolView[] memory items = new DepoistPoolView[](
            _depositPools.length()
        );

        for (uint256 i = 0; i < items.length; i++) {
            items[i] = _makeDepoistPoolView(staker, _depositPools.at(i));
        }
        return items;
    }
}
