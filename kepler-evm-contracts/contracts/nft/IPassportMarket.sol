
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/IERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/IERC721MetadataUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/interfaces/IERC2981Upgradeable.sol";

interface IPassportMarket {
    struct Grade {
        uint256 id;
        uint256 minReferalAmount;
        uint256 maxReferalAmount;
        uint256 commissionRate;
        uint256 discountRate;
    }

    struct NftInfoView {
        address nft;
        uint256 price;
        uint256 maxSupply;
        uint256 sales;
    }

    struct Referral {
        address nft;
        uint256 nftCount;
        address user;
        uint256 fee;
        uint256 discountedFee;
        uint256 reward;
        uint256 time;
    }

    function buy(
        address nft,
        uint256 nftCount,
        address referrer
    ) external;

    function queryGrades() external view returns (Grade[] memory);

    function queryReferrals(address referrer)
        external
        view
        returns (Referral[] memory);

    function queryGrade(address owner) external view returns (Grade memory);

    function querySupportedNfts()
        external
        view
        returns (NftInfoView[] memory views);
}
