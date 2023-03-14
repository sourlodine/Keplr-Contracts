
pragma solidity ^0.8.4;

interface IAssetManager {
    event ClaimToken(
        address indexed token,
        address indexed user,
        uint256 amount,
        uint256 orderId
    );

    event DepositToken(
        address indexed token,
        address indexed user,
        uint256 amount
    );

    event ClaimNFT(
        address indexed nft,
        address indexed user,
        uint256 tokenId,
        uint256 orderId
    );

    event DepositNFT(
        address indexed nft,
        address indexed user,
        uint256 tokenId
    );

    function feeToken() external view returns (address);

    function transactionFee() external view returns (uint256);

    function claimToken(
        address token,
        uint256 amount,
        uint256 orderId,
        bytes memory signature
    ) external;

    function depositToken(address token, uint256 amount) external;

    function claimNFT(
        address nft,
        uint256 tokenId,
        uint256 orderId,
        bytes memory signature
    ) external;

    function depositNFT(address nft, uint256 tokenId) external;
}
