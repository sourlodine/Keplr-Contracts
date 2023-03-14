
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IPassport.sol";
import "./IPassportMarket.sol";
import "../common/SafeAccess.sol";

contract PassportMarket is
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    OwnableUpgradeable,
    IPassportMarket,
    SafeAccess
{
    using EnumerableSet for EnumerableSet.AddressSet;
    uint256 private constant MIN_AMOUNT = 1000e18;

    struct NftInfo {
        uint256 price;
        uint256 maxSupply;
    }

    Grade[] private _grades;

    mapping(address => uint256) private _referrerAmounts;

    EnumerableSet.AddressSet private _supportedNFTs;
    mapping(address => NftInfo) private _nftInfos;
    mapping(address => uint256) private _sales;

    mapping(address => Referral[]) private _referrals;

    address private _stableFeeToken;
    address private _valut;
    mapping(address => uint256) private _buyAmounts;

    function initialize(address stableFeeToken, address vault)
        public
        initializer
    {
        __Ownable_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        _stableFeeToken = stableFeeToken;
        _valut = vault;
    }

    function setGrades(Grade[] memory grades) public onlyOwner {
        delete _grades;
        for (uint256 i; i < grades.length; i++) {
            _grades.push(grades[i]);
        }
    }

    function _buy(
        address nft,
        uint256 nftCount,
        address referrer
    ) private {
        address user = msg.sender;

        require(_valut != address(0), "ZERO_VAULT");
        require(nftCount > 0, "ZERO_NFT_AMOUNT");

        NftInfo memory nftInfo = _nftInfos[nft];
        require(nftInfo.price > 0, "UNKOWN_NFT");

        require(
            _sales[nft] + nftCount <= nftInfo.maxSupply,
            "EXCEED_MAX_SUPPLY"
        );
        _sales[nft] += nftCount;
        uint256 fee = nftInfo.price * nftCount;
        Grade memory grade = queryGrade(referrer);
        uint256 discountRate = grade.discountRate;
        uint256 commissionRate = grade.commissionRate;
        require(discountRate < 100, "EXCEED_MAX_DISCOUNT_RATE");
        require(commissionRate < 100, "EXCEED_MAX_COMMISSION_RATE");

        uint256 discountedFee = fee - (fee * discountRate) / 100;
        _buyAmounts[user] += discountedFee;

        require(
            IERC20(_stableFeeToken).balanceOf(user) >= discountedFee,
            "INSUFFICIENT_TOKEN_BALANCE"
        );
        require(
            IERC20(_stableFeeToken).allowance(user, address(this)) >=
                discountedFee,
            "INSUFFICIENT_TOKEN_ALLOWANCE"
        );

        uint256 reward;

        for (uint256 i; i < nftCount; i++) {
            IPassport(nft).mint(user);
        }

        if (grade.id > 0) {
            _referrerAmounts[referrer] += discountedFee;
            if (commissionRate > 0) {
                reward = (discountedFee * commissionRate) / 100;
            }
            _referrals[referrer].push(
                Referral({
                    nft: nft,
                    nftCount: nftCount,
                    user: user,
                    fee: fee,
                    discountedFee: discountedFee,
                    reward: reward,
                    time: block.timestamp
                })
            );
        }
        if (reward > 0) {
            IERC20(_stableFeeToken).transferFrom(user, referrer, reward);
        }
        IERC20(_stableFeeToken).transferFrom(
            user,
            _valut,
            discountedFee - reward
        );
    }

    function buy(
        address nft,
        uint256 nftCount,
        address referrer
    ) external override nonReentrant whenNotPaused isNotContractCall {
        require(nftCount <= 10, "EXCEED_MAX_NFT_AMOUNT");
        _buy(nft, nftCount, referrer);
    }

    function agencyBuy(address nft, uint256 nftCount)
        external
        nonReentrant
        whenNotPaused
        isNotContractCall
    {
        _buy(nft, nftCount, address(0));
    }

    function addSupportedNFTs(
        address[] memory nfts,
        uint256[] memory prices,
        uint256[] memory supplies
    ) public onlyOwner {
        for (uint256 i = 0; i < nfts.length; i++) {
            address nft = nfts[i];
            _supportedNFTs.add(nft);
            _nftInfos[nft] = NftInfo(prices[i], supplies[i]);
        }
    }

    function removeSupportedNFTs(address[] memory items) public onlyOwner {
        for (uint256 i = 0; i < items.length; i++) {
            _supportedNFTs.remove(items[i]);
            delete _nftInfos[items[i]];
        }
    }

    function queryReferrals(address referrer)
        public
        view
        override
        returns (Referral[] memory)
    {
        return _referrals[referrer];
    }

    function queryGrades() external view override returns (Grade[] memory) {
        return _grades;
    }

    function querySupportedNfts()
        external
        view
        override
        returns (NftInfoView[] memory views)
    {
        views = new NftInfoView[](_supportedNFTs.length());
        for (uint256 i; i < views.length; i++) {
            address nft = _supportedNFTs.at(i);
            views[i] = NftInfoView(
                nft,
                _nftInfos[nft].price,
                _nftInfos[nft].maxSupply,
                _sales[nft]
            );
        }
    }

    function queryGrade(address referrer)
        public
        view
        override
        returns (Grade memory)
    {
        if (referrer != address(0) && _buyAmounts[referrer] >= MIN_AMOUNT) {
            uint256 referalAmount = _referrerAmounts[referrer];
            for (uint256 i; i < _grades.length; i++) {
                Grade memory grade = _grades[i];
                if (
                    grade.minReferalAmount >= referalAmount &&
                    referalAmount < grade.maxReferalAmount
                ) {
                    return grade;
                }
            }
        }
        return Grade(0, 0, 0, 0, 0);
    }
}
