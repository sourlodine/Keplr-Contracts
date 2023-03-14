
pragma solidity ^0.8.4;

import "./CorePool.sol";

contract DepositPool is CorePool {
    function initialize(
        address depositToken_,
        address rewardToken_,
        address rewardPool_,
        address poolFactory_,
        uint256 lockUnitDuration_,
        uint256 lockUnitMultiplier_,
        uint256 maxLockUnits_
    ) public initializer {
        __CorePool_init(
            depositToken_,
            rewardToken_,
            rewardPool_,
            poolFactory_,
            lockUnitDuration_,
            lockUnitMultiplier_,
            maxLockUnits_
        );
    }
}
