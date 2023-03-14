
pragma solidity ^0.8.4;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "../libraries/Signature.sol";
import "../swap/libraries/TransferHelper.sol";
import "../libraries/SafeDecimalMath.sol";
import "../common/SafeAccess.sol";
import "./IMysteryBox.sol";
import "./IKeplerNFT.sol";
import "../oracle/IOracle.sol";

contract MysteryBox is
    ERC721EnumerableUpgradeable,
    OwnableUpgradeable,
    IMysteryBox,
    SafeAccess
{
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;
    using SafeDecimalMath for uint256;
    using StringsUpgradeable for uint256;

    uint8 internal constant USER_MAX_MINT_COUNT = 12;

    uint8 internal constant SUIT_PART_COUNT = 6;
    uint8 internal constant FEMALE = 0;
    uint8 internal constant MALE = 1;

    uint256 public nextTokenId;
    address public oracle;

    PaymentConfig public paymentConfig;
    ReferralConfig public referralConfig;
    MintConfig public mintConfig;

    mapping(uint256 => EnumerableSet.UintSet) private _genderTokenIds;
    mapping(uint256 => uint8) private _genderMintCounts;
    mapping(address => uint8) private _userMintCounts;

    mapping(address => EnumerableSet.UintSet) private _referralTokenIds;

    EnumerableSet.AddressSet private _signers;
    mapping(uint256 => Item) private _items;
    address public mintFeeWallet;
    uint256 public override openStartTime;

    string private _tokenURI;

    function initialize(
        string memory name_,
        string memory symbol_,
        address signer_,
        address oracle_,
        address mintFeeWallet_,
        uint256 openStartTime_
    ) public initializer {
        __Ownable_init();
        __ERC721_init(name_, symbol_);
        _signers.add(msg.sender);
        _signers.add(signer_);
        nextTokenId = 1000;
        oracle = oracle_;
        paymentConfig.genisTime = _currentTimestamp();
        mintFeeWallet = mintFeeWallet_;
        openStartTime = openStartTime_;
    }

    function updateTokenURI(string memory val) public onlyOwner {
        _tokenURI = val;
    }

    function queryTokenURI() public view returns (string memory) {
        return _tokenURI;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721Upgradeable, IERC721MetadataUpgradeable)
        returns (string memory)
    {
        return string(abi.encodePacked(_tokenURI, tokenId.toString()));
    }

    function querySigners() public view returns (address[] memory) {
        address[] memory signers = new address[](_signers.length());
        for (uint256 i; i < signers.length; i++) {
            signers[i] = _signers.at(i);
        }
        return signers;
    }

    function getSigner(address user, bytes memory signature)
        public
        pure
        returns (address)
    {
        return Signature.getSigner(keccak256MintArgs(user), signature);
    }

    function updateOpenStartTime(uint256 val) public onlyOwner {
        openStartTime = val;
    }

    function updateMintFeeWallet(address val) public onlyOwner {
        mintFeeWallet = val;
    }

    function updateOracle(address val) public onlyOwner {
        oracle = val;
    }

    function updateReferralConfig(ReferralConfig memory config)
        public
        onlyOwner
    {
        require(config.rewardRate > 0, "INVALID_REWARD_RATE");
        referralConfig = config;
        emit UpdateReferralConfig(config);
    }

    function updateMintConfig(MintConfig memory config) public onlyOwner {
        mintConfig = config;
        emit UpdateMintConfig(config);
    }

    function updatePaymentConfig(PaymentConfig memory config) public onlyOwner {
        paymentConfig = config;
        emit UpdatePaymentConfig(config);
    }

    function queryPaymentConfig()
        external
        view
        override
        returns (PaymentConfig memory)
    {
        return paymentConfig;
    }

    function queryReferralConfig()
        external
        view
        override
        returns (ReferralConfig memory)
    {
        return referralConfig;
    }

    function queryMintConfig()
        external
        view
        override
        returns (MintConfig memory)
    {
        return mintConfig;
    }

    function queryReferralItems(address referrer)
        public
        view
        override
        returns (Item[] memory items)
    {
        items = new Item[](_referralTokenIds[referrer].length());
        for (uint256 i; i < items.length; i++) {
            uint256 tokenId = _referralTokenIds[referrer].at(i);
            items[i] = _items[tokenId];
        }
    }

    function queryReferralReward(address referal, uint256 tokenId)
        external
        view
        override
        returns (int256)
    {
        Item memory item = _items[tokenId];
        if (item.fee == 0) return -1;
        if (item.claimTime > 0) return -2;
        if (item.referral != referal) return -3;
        if (referralConfig.cliamPrice == 0) return -4;
        if (block.timestamp < referralConfig.claimStartTime) return -5;
        return
            int256(
                item
                    .cost
                    .multiplyDecimal(referralConfig.rewardRate)
                    .divideDecimal(referralConfig.cliamPrice)
            );
    }

    function claimReferralReward(uint256 tokenId) external override {
        _claimReferralReward(tokenId);
    }

    function batchClaimReferralRewards(uint256[] memory tokenIds)
        external
        override
    {
        for (uint256 i; i < tokenIds.length; i++) {
            _claimReferralReward(tokenIds[i]);
        }
    }

    function _claimReferralReward(uint256 tokenId) private {
        address referrer = msg.sender;
        require(
            _referralTokenIds[referrer].contains(tokenId),
            "INVALID_ACCESS"
        );

        Item memory item = _items[tokenId];
        require(item.fee > 0, "INVALID_ITEM");
        require(item.claimTime == 0, "DUPLICATE_CLAIM");
        require(referralConfig.cliamPrice > 0, "INVALID_CLAIM_PRICE");
        require(
            block.timestamp > referralConfig.claimStartTime,
            "INVALID_CLAIM_TIME"
        );

        uint256 price = referralConfig.cliamPrice;
        address rewardToken = referralConfig.rewardToken;
        uint256 amount = item
            .cost
            .multiplyDecimal(referralConfig.rewardRate)
            .divideDecimal(price);

        if (rewardToken == address(0)) {
            require(
                address(this).balance >= amount,
                "INSUFFICIENT_REWARD_AMOUNT"
            );
            payable(referrer).transfer(amount);
        } else {
            require(
                IERC20(rewardToken).balanceOf(address(this)) >= amount,
                "INSUFFICIENT_REWARD_AMOUNT"
            );
            IERC20(rewardToken).transfer(referrer, amount);
        }
        item.claimeAmount = amount;
        item.claimTime = block.timestamp;
        _items[tokenId] = item;
    }

    function getVariableView()
        public
        view
        override
        returns (VariableView memory)
    {
        return
            VariableView({
                currentPrice: _price(),
                maleMintedCount: _genderMintCounts[MALE],
                femaleMintedCount: _genderMintCounts[FEMALE]
            });
    }

    function _price() private view returns (uint256) {
        uint256 t = _currentTimestamp();
        if (t <= paymentConfig.genisTime) {
            return paymentConfig.maxPrice;
        }
        uint256 passedSeconds = t - paymentConfig.genisTime;
        uint256 price = paymentConfig.priceStep *
            (passedSeconds / paymentConfig.priceAdjustInterval) +
            paymentConfig.startPrice;

        if (price >= paymentConfig.maxPrice - paymentConfig.priceStep) {
            price = paymentConfig.maxPrice;
        }

        return price;
    }

    function keccak256MintArgs(address sender)
        public
        pure
        override
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(sender));
    }

    function getMintCount(address user) external view override returns (uint8) {
        return _userMintCounts[user];
    }

    function queryMintFee(uint8 nftCount, bool isWhitelisted)
        public
        view
        returns (uint256)
    {
        uint256 fee = (_price() * nftCount);

        if (isWhitelisted) {
            fee = (fee * (100 - paymentConfig.whitelistDiscount)) / 100;
        }
        return fee;
    }

    function mint(
        bool isSuit,
        uint8 gender,
        uint8 nftCount,
        address referral,
        bytes memory signature
    ) external payable override isNotContractCall returns (uint256 tokenId) {
        address buyer = msg.sender;
        bool isWhitelisted = _verifyMintArgs(
            buyer,
            isSuit,
            gender,
            nftCount,
            signature
        );
        tokenId = nextTokenId++;

        _userMintCounts[buyer] += nftCount;
        _genderTokenIds[gender].add(tokenId);
        _genderMintCounts[gender] += nftCount;
        _mint(buyer, tokenId);

        uint256 fee = queryMintFee(nftCount, isWhitelisted);

        _items[tokenId] = Item({
            tokenId: tokenId,
            referral: referral,
            buyer: buyer,
            fee: fee,
            currency: paymentConfig.currency,
            mintTime: _currentTimestamp(),
            isSuit: isSuit,
            gender: gender,
            nftCount: nftCount,
            cost: IOracle(oracle)
                .queryPrice(paymentConfig.currency)
                .multiplyDecimal(fee),
            claimTime: 0,
            claimeAmount: 0,
            isWhitelisted: isWhitelisted
        });

        if (referral != address(0)) {
            _referralTokenIds[referral].add(tokenId);
        }

        _transferFrom(paymentConfig.currency, buyer, fee);

        emit Mint(
            buyer,
            isSuit,
            gender,
            nftCount,
            paymentConfig.currency,
            fee,
            referral
        );
    }

    function queryItem(uint256 tokenId)
        external
        view
        override
        returns (Item memory)
    {
        return _items[tokenId];
    }

    function keccak256OpenArgs(
        uint256 mysteryBoxId,
        address[] memory nfts,
        uint256[] memory nftTokenIds,
        uint256 deadline
    ) public pure override returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(mysteryBoxId, nfts, nftTokenIds, deadline)
            );
    }

    function open(
        uint256 tokenId,
        address[] memory nfts,
        uint256[] memory nftTokenIds,
        uint256 deadline,
        bytes memory signature
    ) external override isNotContractCall {
        require(deadline > _currentTimestamp(), "EXPIRED");
        require(openStartTime <= _currentTimestamp(), "INVALID_OPEN_TIME");
        bytes32 argsHash = keccak256OpenArgs(
            tokenId,
            nfts,
            nftTokenIds,
            deadline
        );
        require(
            _signers.contains(Signature.getSigner(argsHash, signature)),
            "VERIFY_FAILED"
        );
        require(msg.sender == ownerOf(tokenId), "INVALID_ACCESS");
        Item memory item = _items[tokenId];
        require(item.nftCount == nfts.length, "INVALID_NFTS");
        require(item.nftCount == nftTokenIds.length, "INVALID_TOKEN_IDS");
        for (uint256 i; i < nfts.length; i++) {
            IKeplerNFT(nfts[i]).mintTo(msg.sender, nftTokenIds[i]);
        }
        _burn(tokenId);
        emit Open(msg.sender, tokenId, nfts, nftTokenIds);
    }

    function tokenIdsOfOwner(address owner)
        public
        view
        override
        returns (uint256[] memory tokenIds)
    {
        uint256 balance = balanceOf(owner);
        tokenIds = new uint256[](balance);
        for (uint256 i; i < balance; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(owner, i);
        }
    }

    function itemsOfOwner(address owner)
        external
        view
        override
        returns (Item[] memory items)
    {
        uint256[] memory tokenIds = tokenIdsOfOwner(owner);
        items = new Item[](tokenIds.length);
        for (uint256 i; i < tokenIds.length; i++) {
            items[i] = _items[tokenIds[i]];
        }
    }

    function _currentTimestamp() private view returns (uint256) {
        return block.timestamp;
    }

    function allItems()
        external
        view
        override
        returns (ItemView[] memory items)
    {
        uint256 maleCount = _genderTokenIds[MALE].length();
        uint256 femaleCount = _genderTokenIds[FEMALE].length();
        items = new ItemView[](maleCount + femaleCount);
        uint256 index;

        for (uint256 i; i < maleCount; i++) {
            uint256 tokenId = _genderTokenIds[MALE].at(i);
            items[index] = _toItemView(tokenId, _items[tokenId]);
            index++;
        }

        for (uint256 i; i < femaleCount; i++) {
            uint256 tokenId = _genderTokenIds[FEMALE].at(i);
            items[index] = _toItemView(tokenId, _items[tokenId]);
            index++;
        }
    }

    function _verifyMintArgs(
        address buyer,
        bool isSuit,
        uint8 gender,
        uint8 nftCount,
        bytes memory signature
    ) private view returns (bool isWhitelisted) {
        isWhitelisted = signature.length == 65;
        if (isWhitelisted) {
            require(
                _signers.contains(
                    Signature.getSigner(keccak256MintArgs(buyer), signature)
                ),
                "VERIFY_FAILED"
            );
        }

        require(
            nftCount <= SUIT_PART_COUNT,
            "EXCEED_MYSTERYBOX_MAX_MINT_COUNT"
        );

        if (isSuit) {
            require(nftCount == SUIT_PART_COUNT, "INVALID_NFT_COUNT");
        }
        require(
            _userMintCounts[buyer] + nftCount <= USER_MAX_MINT_COUNT,
            "EXCEED_MAX_MINT_COUNT"
        );

        uint256 maxCount = gender == FEMALE
            ? mintConfig.femaleMax
            : mintConfig.maleMax;

        require(
            _genderTokenIds[gender].length() + nftCount <= maxCount,
            "INSUFFICIENT_INVENTORY"
        );

        require(gender == FEMALE || gender == MALE, "INVALID_GENDER");
    }

    function _transferFrom(
        address currency,
        address from,
        uint256 fee
    ) private {
        if (currency == address(0)) {
            require(msg.value >= fee, "INVALID_MSG_VALUE");
            TransferHelper.safeTransferETH(mintFeeWallet, fee);
        } else {
            IERC20 erc20 = IERC20(currency);
            require(erc20.balanceOf(from) >= fee, "INSUFICIENT_BALANCE");
            require(
                erc20.allowance(from, address(this)) >= fee,
                "INSUFICIENT_ALLOWANCE"
            );
            erc20.transferFrom(from, mintFeeWallet, fee);
        }
    }

    function _toItemView(uint256 tokenId, Item memory item)
        private
        pure
        returns (ItemView memory)
    {
        return
            ItemView({
                tokenId: tokenId,
                isSuit: item.isSuit,
                gender: item.gender,
                nftCount: item.nftCount,
                user: item.buyer,
                fee: item.fee
            });
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
