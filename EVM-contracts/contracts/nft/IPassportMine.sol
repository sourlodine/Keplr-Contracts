
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/IERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/IERC721MetadataUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/interfaces/IERC2981Upgradeable.sol";


interface IPassportMine {
    struct KeplerPassportPublicConfig {
        address passport;
        uint256 price;
        uint256 maxSupply;
    }

    struct KeplerPassportPromotionConfig {
        address passport;
        uint256 stage1Supply;
        uint256 stage1Price;
        uint256 stage2Supply;
        uint256 stage2Price;
    }
    struct UniversePassportConfig {
        address passport;
        uint256 publicPrice;
        uint256 promotionPrice;
        uint256 maxSupply;
    }

    struct GlobalView {
        KeplerPassportPublicConfig keplerPassportPublicConfig;
        KeplerPassportPromotionConfig keplerPassportPromotionConfig;
        UniversePassportConfig universePassportConfig;
        uint256 keplerPassportPublicSaleAmount;
        uint256 keplerPassportPromotionSaleAmount;
        uint256 universePassportSaleAmount;
    }

    struct ReferenceRecording {
        address buyer;
        address passport;
        uint8 nftAmount;
        uint256 currencyAmount;
        uint256 reward;
        uint256 buyTime;
    }

    function queryReferenceRecordings(address referrer)
        external
        view
        returns (ReferenceRecording[] memory);

    function queryGlobalView()
        external
        view
        returns (GlobalView memory globalView);

    function queryBuyAmount(address user, address passport)
        external
        view
        returns (uint256);

    function buyKeplerPassport(
        uint8 amount,
        address referrer,
        uint8 isPromotional,
        bytes memory signature
    ) external payable;

    function buyUniversePassport(
        uint8 amount,
        address referrer,
        uint8 isPromotional,
        bytes memory signature
    ) external payable;
}
