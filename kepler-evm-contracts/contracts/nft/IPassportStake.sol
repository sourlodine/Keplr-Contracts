
pragma solidity ^0.8.4;




interface IPassportStake {
    event Stake(
        address indexed user,
        uint256 indexed tokenId,
        uint256 lockUnits
    );

    event Unstake(address indexed user, uint256 indexed tokenId);

    event DrawLottery(
        uint256 sequence,
        uint256[] tokenIds
    );

    struct UserLottery {
        uint256 sequence;
        uint256 tokenId;
        uint256 reward;
    }

    struct LotteryView {
        uint256 sequence;
        uint256[] tokenIds;
    }

    struct GlobalView {
        address passport;
        uint256 lockUnitSpan;
        uint256 rewardPerDraw;
        uint256 totalTokenIds;
        uint256 totalLockUnits;
        LotteryView[] lotteries;
    }

    struct UserView {
        uint256 pendingReward;
        uint256[] tokenIds;
        uint256[] stakeTimes;
        uint256[] lockUnits;
        UserLottery[] lotteries;
    }

    function stake(uint256 tokenId, uint256 lockUnits) external;

    function batchStake(uint256[] memory tokenIds, uint256 lockUnits) external;

    function unstake(uint256 tokenId) external;

    function batchUnstake(uint256[] memory tokenIds) external;

    function claim() external;

    function queryGlobalView() external view returns (GlobalView memory gv);

    function queryUserView(address user)
        external
        view
        returns (UserView memory uv);
}
