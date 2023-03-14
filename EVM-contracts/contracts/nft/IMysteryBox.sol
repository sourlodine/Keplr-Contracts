
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/IERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/IERC721MetadataUpgradeable.sol";

interface IMysteryBox is
    IERC721MetadataUpgradeable,
    IERC721EnumerableUpgradeable
{
    event Mint(
        address indexed user,
        bool isSuit,
        uint8 gender,
        uint8 nftCount,
        address currency,
        uint256 fee,
        address referral
    );

    event Open(
        address indexed user,
        uint256 tokenId,
        address[] nfts,
        uint256[] nftTokenIds
    );

    event UpdateReferralConfig(ReferralConfig config);

    event UpdatePaymentConfig(PaymentConfig config);

    event UpdateMintConfig(MintConfig config);

    struct ReferralConfig {
        address rewardToken;
        uint256 rewardRate;
        uint256 claimStartTime;
        uint256 cliamPrice;
    }

    struct PaymentConfig {
        address currency;
        uint256 startPrice;
        uint256 priceAdjustInterval;
        uint256 maxPrice;
        uint256 genisTime;
        uint256 priceStep;
        uint8 whitelistDiscount;
    }

    struct MintConfig {
        uint256 maleMax;
        uint256 femaleMax;
    }

    struct VariableView {
        uint256 currentPrice;
        uint256 maleMintedCount;
        uint256 femaleMintedCount;
    }

    struct Item {
        uint256 tokenId;
        address buyer;
        address referral;
        uint256 fee;
        address currency;
        uint256 mintTime;
        bool isSuit;
        uint8 gender;
        uint8 nftCount;
        uint256 cost;
        uint256 claimTime;
        uint256 claimeAmount;
        bool isWhitelisted;
    }

    struct ItemView {
        uint256 tokenId;
        bool isSuit;
        uint8 gender;
        uint8 nftCount;
        address user;
        uint256 fee;
    }

    function openStartTime() external view returns (uint256);

    function allItems() external view returns (ItemView[] memory items);

    function getMintCount(address user) external view returns (uint8);

    function getVariableView() external view returns (VariableView memory);

    function keccak256MintArgs(address sender) external pure returns (bytes32);

    function mint(
        bool isSuit,
        uint8 gender,
        uint8 nftCount,
        address referral,
        bytes memory signature
    )
        external
        payable
        returns (
            uint256 tokenId
        );

    function keccak256OpenArgs(
        uint256 mysteryBoxId,
        address[] memory nfts,
        uint256[] memory nftTokenIds,
        uint256 deadline
    ) external pure returns (bytes32);

    function open(
        uint256 tokenId,
        address[] memory nfts,
        uint256[] memory nftTokenIds,
        uint256 deadline,
        bytes memory signature
    ) external;

    function tokenIdsOfOwner(address owner)
        external
        view
        returns (uint256[] memory tokenIds);

    function itemsOfOwner(address owner)
        external
        view
        returns (Item[] memory items);

    function queryReferralItems(
        address referral
    ) external view returns (Item[] memory items);

    function queryReferralReward(
        address referal,
        uint256 tokenId
    ) external view returns (int256);

    function claimReferralReward(
        uint256 tokenId
    ) external;

    function batchClaimReferralRewards(uint256[] memory tokenIds) external;

    function queryPaymentConfig() external view returns (PaymentConfig memory);

    function queryReferralConfig()
        external
        view
        returns (ReferralConfig memory);

    function queryMintConfig() external view returns (MintConfig memory);

    function queryItem(uint256 tokenId) external view returns (Item memory);
}
