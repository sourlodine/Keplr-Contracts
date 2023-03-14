
pragma solidity ^0.8.4;

interface IPresale {
    event Buy(
        address indexed user,
        address indexed referer,
        uint256 buyAmount,
        uint256 reward
    );

    event Claim(
        address indexed user,
        uint256 index,
        uint256 amount
    );

    struct BuyRecord {
        address buyer;
        address referrer;
        uint256 vTokenAmount;
        address feeToken;
        uint256 feeTokenAmount;
        uint256 referrerReward;
        uint256 buyTime;
        uint256 lockPeriods;
    }

    struct Claimable {
        uint256 index;
        uint256 amount;
    }

    struct Config {
        uint256 claimStartTime;
        uint256 commissionRate;
        address vToken;
        address token;
        address feeWallet;
        uint256 saleAmountPerRound;
        uint256 claimInterval;
        uint256 minBuyAmount;
        uint256 maxBuyAmount;
        uint256 refeererMinBuyAmount;
    }

    function buy(
        address usdToken,
        uint256 usdAmount,
        uint256 lockPeriods,
        address referrer
    ) external;

    function queryStableCoins()
        external
        view
        returns (address[] memory stableCoins);

    function claim() external;

    function queryClaimAmount(address user, uint256 claimIndex)
        external
        view
        returns (uint256 claimAmount);

    function queryClaimables(address user)
        external
        view
        returns (Claimable[] memory);

    function queryBuyRecords(address user)
        external
        view
        returns (BuyRecord[] memory);

    function queryConfig() external view returns (Config memory);

    function queryRoundPrices() external view returns (uint256[] memory);

    function querySaledUsdAmount() external view returns (uint256);
}
