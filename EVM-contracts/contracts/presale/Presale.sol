
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../swap/libraries/TransferHelper.sol";
import "../libraries/SafeDecimalMath.sol";
import "../common/SafeAccess.sol";
import "../tokens/IToken.sol";
import "./IPresale.sol";

contract Presale is
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    OwnableUpgradeable,
    SafeAccess,
    IPresale
{
    using EnumerableSet for EnumerableSet.AddressSet;
    uint256 public constant UNIT = 1e18;

    Config public config;

    EnumerableSet.AddressSet private _stableCoins;
    uint256[] public roundPrices;

    uint256 public saledUsdAmount;

    mapping(address => BuyRecord[]) public buyRecords;

    mapping(address => uint256) public claimedCounts;

    function initialize(uint256 basePrice) public initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        _initPrices(basePrice);
    }

    function updateConfig(Config memory c) public onlyOwner {
        config = c;
    }

    function buy(
        address usdToken,
        uint256 usdAmount,
        uint256 lockPeriods,
        address referrer
    ) external override {
        require(
            block.timestamp < config.claimStartTime,
            "BUY_FORBIDDEN_AFTER_CLAIM_STARTED"
        );

        address user = msg.sender;
        require(user != referrer, "INVALID_REFERRER");
        require(
            config.commissionRate < 100 && config.commissionRate > 0,
            "INVALID_COMMISSION_RATE"
        );
        require(_stableCoins.contains(usdToken), "UNSUPPORTED_STABLE_COIN");
        require(usdAmount >= config.minBuyAmount, "INSUFFICIENT_BUY_AMOUNT");
        require(usdAmount <= config.maxBuyAmount, "EXCEED_BUY_AMOUNT");
        require(config.feeWallet != address(0), "ZERO_VAULT");
        require(lockPeriods >= 6 && lockPeriods <= 60, "INVALID_LOCK_MONTH");

        require(
            IToken(usdToken).balanceOf(user) >= usdAmount,
            "INSUFFICIENT_TOKEN_BALANCE"
        );
        require(
            IToken(usdToken).allowance(user, address(this)) >= usdAmount,
            "INSUFFICIENT_TOKEN_ALLOWANCE"
        );
        uint256 vTokenAmount = getBuyablevTokenAmount(usdAmount);
        uint256 reward;
        if (queryTotalBuyAmount(referrer) >= config.refeererMinBuyAmount) {
            reward = (usdAmount * config.commissionRate) / 100;
        }
        saledUsdAmount += usdAmount;
        buyRecords[user].push(
            BuyRecord({
                buyer: user,
                referrer: referrer,
                vTokenAmount: vTokenAmount,
                feeToken: usdToken,
                feeTokenAmount: usdAmount,
                referrerReward: reward,
                buyTime: block.timestamp,
                lockPeriods: lockPeriods
            })
        );

        if (reward > 0) {
            IToken(usdToken).transferFrom(user, referrer, reward);
        }
        IToken(usdToken).transferFrom(
            user,
            config.feeWallet,
            usdAmount - reward
        );
        require(
            IToken(config.vToken).balanceOf(address(this)) >= vTokenAmount,
            "INSUFFICIENT_VTOKEN_BALANCE"
        );
        IToken(config.vToken).transfer(user, vTokenAmount);
        emit Buy(user, referrer, usdAmount, reward);
    }

    function queryClaimables(address user)
        public
        view
        override
        returns (Claimable[] memory)
    {
        if (block.timestamp <= config.claimStartTime) {
            return new Claimable[](0);
        }

        uint256 maxClaimCout = SafeDecimalMath.min(
            (block.timestamp - config.claimStartTime) / config.claimInterval,
            queryMaxCliamCount(user)
        );

        uint256 claimedCount = claimedCounts[user];
        if (maxClaimCout <= claimedCount) {
            return new Claimable[](0);
        }

        Claimable[] memory claimables = new Claimable[](
            maxClaimCout - claimedCount
        );
        for (uint256 i; i < claimables.length; i++) {
            uint256 index = i + claimedCount;
            uint256 amount = queryClaimAmount(user, index);
            claimables[i] = Claimable(index, amount);
        }
        return claimables;
    }

    function claim() external override {
        address user = msg.sender;
        Claimable[] memory claimables = queryClaimables(user);
        require(claimables.length > 0, "NOTHING_TO_CLAIM");
        uint256 totalAmount = 0;
        uint256 claimedCount = claimedCounts[user];
        for (uint256 i; i < claimables.length; i++) {
            totalAmount += claimables[i].amount;
            emit Claim(user, claimedCount + i, claimables[i].amount);
        }
        claimedCounts[user] += claimables.length;

        require(
            IToken(config.vToken).balanceOf(user) >= totalAmount,
            "INSUFFICIENT_TOKEN_BALANCE"
        );
        require(
            IToken(config.vToken).allowance(user, address(this)) >= totalAmount,
            "INSUFFICIENT_TOKEN_ALLOWANCE"
        );
        IToken(config.vToken).transferFrom(user, address(this), totalAmount);
        IToken(config.vToken).burn(totalAmount);

        require(
            IToken(config.token).balanceOf(address(this)) >= totalAmount,
            "INSUFFICIENT_KEPL_BALANCE"
        );
        IToken(config.token).transfer(user, totalAmount);
    }

    function addStableCoins(address[] memory items) public onlyOwner {
        for (uint256 i; i < items.length; i++) {
            _stableCoins.add(items[i]);
        }
    }

    function removeStableCoins(address[] memory items) public onlyOwner {
        for (uint256 i; i < items.length; i++) {
            _stableCoins.remove(items[i]);
        }
    }

    function queryStableCoins()
        external
        view
        override
        returns (address[] memory stableCoins)
    {
        stableCoins = new address[](_stableCoins.length());
        for (uint256 i; i < stableCoins.length; i++) {
            stableCoins[i] = _stableCoins.at(i);
        }
    }

    function queryTotalBuyAmount(address user)
        private
        view
        returns (uint256 buyAmount)
    {
        if (user != address(0)) {
            for (uint256 i; i < buyRecords[user].length; i++) {
                buyAmount += buyRecords[user][i].feeTokenAmount;
            }
        }
    }

    function queryMaxCliamCount(address user)
        private
        view
        returns (uint256 claimCount)
    {
        for (uint256 i; i < buyRecords[user].length; i++) {
            uint256 lockPeriods = buyRecords[user][i].lockPeriods;
            if (claimCount < lockPeriods) {
                claimCount = lockPeriods;
            }
        }
    }

    function queryClaimAmount(address user, uint256 claimIndex)
        public
        view
        override
        returns (uint256 claimAmount)
    {
        for (uint256 i; i < buyRecords[user].length; i++) {
            BuyRecord memory record = buyRecords[user][i];
            if (record.lockPeriods > claimIndex) {
                claimAmount += record.vTokenAmount / record.lockPeriods;
            }
        }
    }

    function getBuyablevTokenAmount(uint256 usdAmount)
        private
        view
        returns (uint256)
    {
        uint256 saledAmount = saledUsdAmount;
        uint256 saleAmountPerRound = config.saleAmountPerRound;
        uint256 round = saledAmount / saleAmountPerRound;

        uint256 vTokenAmount = 0;
        for (uint256 i = round; i < roundPrices.length; i++) {
            uint256 roundMaxAmount = (i + 1) * saleAmountPerRound;
            if (saledAmount + usdAmount > roundMaxAmount) {
                uint256 amount = roundMaxAmount - saledAmount;
                vTokenAmount += (amount * UNIT) / roundPrices[i];
                usdAmount -= amount;
                saledAmount += amount;
            } else {
                vTokenAmount += (usdAmount * UNIT) / roundPrices[i];
                break;
            }
        }
        return vTokenAmount;
    }

    function _queryRoundPrice(
        uint256 basePrice,
        uint256 inflationRate,
        uint256 round
    ) private pure returns (uint256) {
        if (round == 0) {
            return basePrice;
        } else {
            uint256 lastRoundPrice = _queryRoundPrice(
                basePrice,
                inflationRate,
                round - 1
            );
            return (lastRoundPrice * (100 + inflationRate)) / 100;
        }
    }

    function updateBasicPrice(uint256 val) external onlyOwner {
        uint256 roundCount = 10;
        require(roundPrices.length == roundCount, "INVALID_ROUND_PRICES");
        uint256 price = val;
        for (uint256 i; i < roundCount; i++) {
            roundPrices[i] = price;
            price = (price * 105) / 100;
            if (i > 2) {
                break;
            }
        }
    }

    function _initPrices(uint256 basePrice) private {
        uint256 roundCount = 10;
        uint256 inflationRate = 5;
        uint256[] memory prices = new uint256[](roundCount);
        uint256 price = basePrice;
        for (uint256 i; i < roundCount; i++) {
            prices[i] = price;
            price = (price * (100 + inflationRate)) / 100;
        }
        roundPrices = prices;
    }

    function queryBuyRecords(address user)
        external
        view
        override
        returns (BuyRecord[] memory)
    {
        return buyRecords[user];
    }

    function queryConfig() external view override returns (Config memory) {
        return config;
    }

    function queryRoundPrices()
        external
        view
        override
        returns (uint256[] memory)
    {
        return roundPrices;
    }

    function querySaledUsdAmount() public view override returns (uint256) {
        return saledUsdAmount;
    }

    function emergencyWithdraw(
        address token,
        address to,
        uint256 amount
    ) public onlyOwner {
        if (token == address(0)) {
            TransferHelper.safeTransferETH(to, amount);
        } else {
            TransferHelper.safeTransfer(token, to, amount);
        }
    }
}
