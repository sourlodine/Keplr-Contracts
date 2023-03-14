
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IPassport.sol";
import "./IPassportMine.sol";
import "../common/SafeAccess.sol";
import "../common/TokenTransferer.sol";
import "../libraries/Signature.sol";

contract PassportMine is
    IPassportMine,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    OwnableUpgradeable,
    SafeAccess,
    TokenTransferer
{
    uint8 private constant MAX_BUY_AMOUNT = 2;

    uint8 private constant COMMISSION_RATE = 5;

    uint8 private constant ITEM_KEPLER_PUBLIC_SALE_AMOUNT = 1;
    uint8 private constant ITEM_KEPLER_PROMOTION_SALE_AMOUNT = 2;
    uint8 private constant ITEM_UNIVERSE_SALE_AMOUNT = 3;

    KeplerPassportPublicConfig private _keplerPassportPublicConfig;
    KeplerPassportPromotionConfig private _keplerPassportPromotionConfig;
    UniversePassportConfig private _universePassportConfig;

    address private _signer;
    address private _currency;
    address private _vault;

    mapping(address => uint256) private _userBuyAmounts;
    mapping(uint8 => uint256) private _passportSaleAmounts;

    mapping(address => ReferenceRecording[]) private _referenceRecordings;

    mapping(address => mapping(address => uint256))
        private _userPassportBuyAmounts;

    function initialize(
        address signer,
        address currency,
        address vault
    ) public initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        _signer = signer;
        _currency = currency;
        _vault = vault;
    }

    function updateKeplerPassportPublicConfig(
        KeplerPassportPublicConfig memory val
    ) public onlyOwner {
        _keplerPassportPublicConfig = val;
    }

    function updateKeplerPassportPromotionConfig(
        KeplerPassportPromotionConfig memory val
    ) public onlyOwner {
        _keplerPassportPromotionConfig = val;
    }

    function updateUniversePassportConfig(UniversePassportConfig memory val)
        public
        onlyOwner
    {
        _universePassportConfig = val;
    }

    function queryBuyAmount(address user, address passport)
        external
        view
        override
        returns (uint256)
    {
        return _userPassportBuyAmounts[user][passport];
    }

    function queryGlobalView()
        external
        view
        override
        returns (GlobalView memory globalView)
    {
        globalView = GlobalView({
            keplerPassportPublicConfig: _keplerPassportPublicConfig,
            keplerPassportPromotionConfig: _keplerPassportPromotionConfig,
            universePassportConfig: _universePassportConfig,
            keplerPassportPublicSaleAmount: _passportSaleAmounts[
                ITEM_KEPLER_PUBLIC_SALE_AMOUNT
            ],
            keplerPassportPromotionSaleAmount: _passportSaleAmounts[
                ITEM_KEPLER_PROMOTION_SALE_AMOUNT
            ],
            universePassportSaleAmount: _passportSaleAmounts[
                ITEM_UNIVERSE_SALE_AMOUNT
            ]
        });
    }

    function buyKeplerPassport(
        uint8 amount,
        address referrer,
        uint8 isPromotional,
        bytes memory signature
    ) external payable override isNotContractCall nonReentrant whenNotPaused {
        _verifySignature(amount, referrer, isPromotional, signature);
        require(amount > 0, "ZERO_AMOUNT");
        require(msg.sender != referrer, "INVALID_REFERRER");
        KeplerPassportPublicConfig memory config = _keplerPassportPublicConfig;
        require(config.price > 0, "NFT_NOT_SUPPORT");
        (
            address passport,
            uint8 itemId,
            uint256 totalSupply,
            uint256 tokenAmount
        ) = isPromotional == 1
                ? _getPromotionKeplerParmeters(amount)
                : _getPublicKeplerParmeters(amount);

        _verifyAndUpdateBuyAmount(passport, amount);
        _verifyAndUpdateSaleAmount(itemId, amount, totalSupply);
        _mintPassport(passport, amount);
        transferTokenFrom(_currency, msg.sender, tokenAmount);
        uint256 reward = _transferOut(referrer, _currency, tokenAmount);
        if (reward > 0) {
            _referenceRecordings[referrer].push(
                ReferenceRecording({
                    buyer: msg.sender,
                    passport: passport,
                    nftAmount: amount,
                    currencyAmount: tokenAmount,
                    reward: reward,
                    buyTime: block.timestamp
                })
            );
        }
    }

    function buyUniversePassport(
        uint8 amount,
        address referrer,
        uint8 isPromotional,
        bytes memory signature
    ) external payable override isNotContractCall nonReentrant whenNotPaused {
        _verifySignature(amount, referrer, isPromotional, signature);
        require(amount > 0, "ZERO_AMOUNT");
        require(msg.sender != referrer, "INVALID_REFERRER");
        (
            address passport,
            uint8 itemId,
            uint256 totalSupply,
            uint256 tokenAmount
        ) = _getUniverseParmeters(isPromotional, amount);

        _verifyAndUpdateBuyAmount(passport, amount);
        _verifyAndUpdateSaleAmount(itemId, amount, totalSupply);
        _mintPassport(passport, amount);
        transferTokenFrom(_currency, msg.sender, tokenAmount);
        uint256 reward = _transferOut(referrer, _currency, tokenAmount);
        if (reward > 0) {
            _referenceRecordings[referrer].push(
                ReferenceRecording({
                    buyer: msg.sender,
                    passport: passport,
                    nftAmount: amount,
                    currencyAmount: tokenAmount,
                    reward: reward,
                    buyTime: block.timestamp
                })
            );
        }
    }

    function _mintPassport(address passport, uint256 amount) private {
        for (uint256 i; i < amount; i++) {
            IPassport(passport).mint(msg.sender);
        }
    }

    function _transferOut(
        address referrer,
        address currency,
        uint256 tokenAmount
    ) private returns (uint256 commissionAmount) {
        commissionAmount = 0;
        if (referrer != address(0)) {
            commissionAmount = (tokenAmount * COMMISSION_RATE) / 100;
            transferTokenTo(currency, referrer, commissionAmount);
        }
        transferTokenTo(currency, _vault, tokenAmount - commissionAmount);
    }

    function _verifyAndUpdateSaleAmount(
        uint8 item,
        uint256 amount,
        uint256 maxSupply
    ) private {
        require(
            _passportSaleAmounts[item] + amount <= maxSupply,
            "EXCEED_SALE_SUPPLY"
        );
        _passportSaleAmounts[item] += amount;
    }

    function _verifyAndUpdateBuyAmount(address passport, uint256 amount)
        private
    {
        require(
            _userPassportBuyAmounts[msg.sender][passport] + amount <=
                MAX_BUY_AMOUNT,
            "EXCEED_MAX_BUY_AMOUNT"
        );

        _userPassportBuyAmounts[msg.sender][passport] += amount;
    }

    function _verifySignature(
        uint8 amount,
        address referrer,
        uint8 isPromotional,
        bytes memory signature
    ) private view {
        require(
            _signer ==
                Signature.getSigner(
                    keccak256Args(msg.sender, amount, referrer, isPromotional),
                    signature
                ),
            "INVALID_SIGNATURE"
        );
    }

    function _getUniverseParmeters(uint8 isPromotional, uint256 amount)
        private
        view
        returns (
            address passport,
            uint8 itemId,
            uint256 totalSupply,
            uint256 tokenAmount
        )
    {
        UniversePassportConfig memory config = _universePassportConfig;
        require(config.publicPrice > 0, "NFT_NOT_SUPPORT");
        itemId = ITEM_UNIVERSE_SALE_AMOUNT;
        tokenAmount =
            (isPromotional == 1 ? config.promotionPrice : config.publicPrice) *
            amount;
        totalSupply = config.maxSupply;
        passport = config.passport;
    }

    function _getPromotionKeplerParmeters(uint256 amount)
        private
        view
        returns (
            address passport,
            uint8 itemId,
            uint256 totalSupply,
            uint256 tokenAmount
        )
    {
        KeplerPassportPromotionConfig
            memory config = _keplerPassportPromotionConfig;
        require(config.stage1Price > 0, "NFT_NOT_SUPPORT");
        passport = config.passport;
        itemId = ITEM_KEPLER_PROMOTION_SALE_AMOUNT;
        totalSupply = config.stage1Supply + config.stage2Supply;
        tokenAmount = 0;
        for (uint256 i = 1; i <= amount; i++) {
            if (_passportSaleAmounts[itemId] + i <= config.stage1Supply) {
                tokenAmount += config.stage1Price;
            } else {
                tokenAmount += config.stage2Price;
            }
        }
    }

    function queryReferenceRecordings(address referrer)
        external
        view
        override
        returns (ReferenceRecording[] memory)
    {
        return _referenceRecordings[referrer];
    }

    function _getPublicKeplerParmeters(uint256 amount)
        private
        view
        returns (
            address passport,
            uint8 itemId,
            uint256 totalSupply,
            uint256 tokenAmount
        )
    {
        KeplerPassportPublicConfig memory config = _keplerPassportPublicConfig;
        require(config.price > 0, "NFT_NOT_SUPPORT");
        passport = config.passport;
        itemId = ITEM_KEPLER_PUBLIC_SALE_AMOUNT;
        totalSupply = config.maxSupply;
        tokenAmount = config.price * amount;
    }

    function keccak256Args(
        address sender,
        uint8 amount,
        address referrer,
        uint8 isPromotional
    ) public pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(sender, amount, referrer, isPromotional)
            );
    }
}
