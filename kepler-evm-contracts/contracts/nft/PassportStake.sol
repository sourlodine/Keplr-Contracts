
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./IPassportStake.sol";
import "../common/SafeAccess.sol";
import "../common/TokenTransferer.sol";
import "../libraries/SafeDecimalMath.sol";
import "../common/NFTTransferer.sol";
import "../oracle/VRFConsumer.sol";

contract PassportStake is
    IPassportStake,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    OwnableUpgradeable,
    SafeAccess,
    TokenTransferer,
    VRFConsumer,
    NFTTransferer
{
    using EnumerableSet for EnumerableSet.UintSet;
    using SafeDecimalMath for uint256;

    uint256 private _lotterySequence;
    address private _passport;
    address private _rewardToken;
    address private _proxy;

    uint256 private _rewardPerDraw;
    uint256 private _minimumStakeTime;

    uint256 private _lockUnitSpan;

    EnumerableSet.UintSet private _tokenIds;

    mapping(address => EnumerableSet.UintSet) private _userTokenIds;
    mapping(uint256 => uint256) private _lockUnits;
    mapping(uint256 => uint256) private _stakeTimes;
    mapping(uint256 => uint256[]) private _lotteries;
    mapping(uint256 => address) private _tokenIdOwners;

    mapping(address => uint256) private _pendingRewards;
    mapping(address => UserLottery[]) private _userLotteries;

    function initialize(
        address proxy,
        address passport,
        address rewardToken,
        uint256 rewardPerDraw,
        uint256 minimumStakeTime,
        uint256 lockUnitSpan
    ) public initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        _passport = passport;
        _rewardToken = rewardToken;
        _lotterySequence = 1;
        _rewardPerDraw = rewardPerDraw;
        _proxy = proxy;
        _minimumStakeTime = minimumStakeTime;
        _lockUnitSpan = lockUnitSpan;
    }

    function batchStake(uint256[] memory tokenIds, uint256 lockUnits)
        external
        override
        isNotContractCall
        nonReentrant
        whenNotPaused
    {
        for (uint256 i; i < tokenIds.length; i++) {
            _stake(tokenIds[i], lockUnits);
        }
    }

    function stake(uint256 tokenId, uint256 lockUnits)
        external
        override
        isNotContractCall
        nonReentrant
        whenNotPaused
    {
        _stake(tokenId, lockUnits);
    }

    function _stake(uint256 tokenId, uint256 lockUnits) private {
        address user = msg.sender;
        require(lockUnits > 0, "INVLAID_LOCK_WEEKS_PARAMETER");
        require(_userTokenIds[user].add(tokenId), "INVALID_TOKEN_ID");
        require(_tokenIds.add(tokenId), "INVALID_TOKEN_ID");

        _lockUnits[tokenId] = lockUnits;
        _stakeTimes[tokenId] = block.timestamp;
        _tokenIdOwners[tokenId] = user;
        transferNFTFrom(_passport, user, tokenId);
        emit Stake(user, tokenId, lockUnits);
    }

    function unstake(uint256 tokenId)
        external
        override
        isNotContractCall
        nonReentrant
        whenNotPaused
    {
        _unstake(tokenId);
    }

    function batchUnstake(uint256[] memory tokenIds)
        external
        override
        isNotContractCall
        nonReentrant
        whenNotPaused
    {
        for (uint256 i; i < tokenIds.length; i++) {
            _unstake(tokenIds[i]);
        }
    }

    function _unstake(uint256 tokenId) private {
        address user = msg.sender;
        uint256 stakeTime = _stakeTimes[tokenId];
        uint256 lockUnits = _lockUnits[tokenId];
        require(stakeTime > 0 && lockUnits > 0, "INVLAID_ACCESS");

        require(
            stakeTime + lockUnits * _lockUnitSpan < block.timestamp,
            "INSUFFICIENT_LOCK_TIME"
        );

        require(_userTokenIds[user].remove(tokenId), "INVALID_TOKEN_ID");
        require(_tokenIds.remove(tokenId), "INVALID_TOKEN_ID");
        delete _stakeTimes[tokenId];
        delete _lockUnits[tokenId];
        delete _tokenIdOwners[tokenId];
        transferNFTTo(_passport, user, tokenId);
        emit Unstake(user, tokenId);
    }

    function consumeRandomWords(uint256[] memory randomWords)
        external
        override
    {
        uint256 randomNumber = randomWords[0];
        require(
            msg.sender == _proxy || msg.sender == owner(),
            "INVALID_ACCESS"
        );
        uint256[] memory tokenIds = new uint256[](_tokenIds.length());
        uint256 length;
        uint256 current = block.timestamp;
        for (uint256 i; i < tokenIds.length; i++) {
            uint256 tokenId = _tokenIds.at(i);
            if (current - _stakeTimes[tokenId] >= _minimumStakeTime) {
                tokenIds[length] = tokenId;
                length += 1;
            }
        }
        require(length > 0, "NON_QUALIFIED_TOKEN_ID");

        uint256 luckyCount = length > 10 ? length / 10 : 1;
        uint256 rewardPerLucky = _rewardPerDraw / luckyCount;
        uint256[] memory luckyTokenIds = new uint256[](luckyCount);
        for (uint256 i = 0; i < luckyCount; i++) {
            uint256 index = _drawOneLottery(
                tokenIds,
                length,
                randomNumber + i * 1024 * 1024
            );
            uint256 tokenId = tokenIds[index];
            luckyTokenIds[i] = tokenId;
            tokenIds[index] = tokenIds[length - 1];
            length = length - 1;
            _pendingRewards[_tokenIdOwners[tokenId]] += rewardPerLucky;
            _userLotteries[_tokenIdOwners[tokenId]].push(
                UserLottery(_lotterySequence, tokenId, rewardPerLucky)
            );
        }
        _lotteries[_lotterySequence] = luckyTokenIds;
        emit DrawLottery(_lotterySequence, luckyTokenIds);
        _lotterySequence++;
    }

    function _drawOneLottery(
        uint256[] memory tokenIds,
        uint256 length,
        uint256 randomNumber
    ) private view returns (uint256) {
        uint256 ticket = 0;
        uint256[] memory tickets = new uint256[](length);
        uint256 span = _lockUnitSpan;
        for (uint256 i; i < length; i++) {
            ticket += _lockUnits[tokenIds[i]] * span;
            tickets[i] = ticket;
        }
        uint256 randomTicket = uint256(
            keccak256(abi.encodePacked(randomNumber))
        ) % ticket;

        uint256 lastTicket = 0;
        for (uint256 i; i < length; i++) {
            if (lastTicket < randomTicket && randomTicket <= tickets[i]) {
                return i;
            }
            lastTicket = tickets[i];
        }
        return 0;
    }

    function claim()
        external
        override
        isNotContractCall
        nonReentrant
        whenNotPaused
    {
        address user = msg.sender;
        uint256 pendingReward = _pendingRewards[user];
        require(pendingReward > 0, "NO_REWARD");
        _pendingRewards[user] = 0;
        transferTokenTo(_rewardToken, user, pendingReward);
    }

    function queryUserView(address user)
        external
        view
        override
        returns (UserView memory uv)
    {
        uv.pendingReward = queryPendingReward(user);
        uv.tokenIds = queryUserTokenIds(user);
        uv.lotteries = _userLotteries[user];
        uint256[] memory stakeTimes = new uint256[](uv.tokenIds.length);
        uint256[] memory lockUnits = new uint256[](uv.tokenIds.length);
        for (uint256 i; i < uv.tokenIds.length; i++) {
            stakeTimes[i] = _stakeTimes[uv.tokenIds[i]];
            lockUnits[i] = _lockUnits[uv.tokenIds[i]];
        }
        uv.stakeTimes = stakeTimes;
        uv.lockUnits = lockUnits;
    }

    function queryGlobalView()
        external
        view
        override
        returns (GlobalView memory gv)
    {
        LotteryView[] memory lotteries = new LotteryView[](
            _lotterySequence - 1
        );
        for (uint256 i = 0; i < lotteries.length; i++) {
            lotteries[i] = LotteryView(i + 1, _lotteries[i + 1]);
        }
        gv.lockUnitSpan = _lockUnitSpan;
        gv.lotteries = lotteries;
        gv.passport = _passport;
        gv.rewardPerDraw = _rewardPerDraw;
        gv.totalTokenIds = _tokenIds.length();
        uint256 totalLockUnits;
        for (uint256 i; i < _tokenIds.length(); i++) {
            totalLockUnits += _lockUnits[_tokenIds.at(i)];
        }
        gv.totalLockUnits = totalLockUnits;
    }

    function queryPendingReward(address user) private view returns (uint256) {
        return _pendingRewards[user];
    }

    function queryUserTokenIds(address user)
        private
        view
        returns (uint256[] memory tokenIds)
    {
        tokenIds = new uint256[](_userTokenIds[user].length());
        for (uint256 i; i < tokenIds.length; i++) {
            tokenIds[i] = _userTokenIds[user].at(i);
        }
    }
}
