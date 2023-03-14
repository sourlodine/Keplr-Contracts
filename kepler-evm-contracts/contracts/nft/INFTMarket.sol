
pragma solidity ^0.8.4;

interface INFTMarket {
    event NFTReceived(
        address operator,
        address from,
        uint256 tokenId,
        bytes data
    );

    struct Item {
        uint256 id;
        address nft;
        uint256 tokenId;
        address currency;
        uint256 price;
        uint8 status;
        address seller;
        address buyer;
    }

    function transactionFeeRate() external view returns (uint256);

    function getSupportedCurrencies()
        external
        view
        returns (address[] memory currencies);

    function getSupportedNFTs() external view returns (address[] memory nfts);


    function getItems(
        uint8 status
    ) external view returns (Item[] memory items);

    function encode(
        uint256 id,
        address nft,
        uint256 tokenId,
        address currency,
        uint256 price,
        uint256 deadline
    ) external pure returns (bytes32);

    function open(
        uint256 id,
        address nft,
        uint256 tokenId,
        address currency,
        uint256 price,
        uint256 deadline,
        bytes memory signature
    ) external;

    function buy(uint256 itemId) external payable;

    function close(uint256 itemId) external;

    function getItem(uint256 itemId) external view returns (Item memory);
}
