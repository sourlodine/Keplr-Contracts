
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "../swap/libraries/TransferHelper.sol";
import "../libraries/Signature.sol";
import "../common/SafeAccess.sol";
import "../common/TokenTransferer.sol";
import "../common/NFTTransferer.sol";
import "./IAssetManager.sol";

contract AssetManager is
    IAssetManager,
    OwnableUpgradeable,
    TokenTransferer,
    NFTTransferer,
    SafeAccess
{
    mapping(uint256 => uint8) private _orderIds;

    address public override feeToken;

    uint256 public override transactionFee;

    address public signer;

    function initialize(
        address feeToken_,
        uint256 transactionFee_,
        address signer_
    ) public initializer {
        __Ownable_init();
        feeToken = feeToken_;
        transactionFee = transactionFee_;
        signer = signer_;
    }

    function updateFeeToken(address feeToken_) public onlyOwner {
        feeToken = feeToken_;
    }

    function updateTransactionFee(uint256 transactionFee_) public onlyOwner {
        transactionFee = transactionFee_;
    }

    function claimToken(
        address token,
        uint256 amount,
        uint256 orderId,
        bytes memory signature
    ) external override isNotContractCall {
        address user = msg.sender;
        _verifySignature(token, user, amount, orderId, signature);
        require(_orderIds[orderId] == 0, "DUPLICATE_DEPOSIT");
        _orderIds[orderId] = 1;
        _chargeFee();
        transferTokenTo(token, user, amount);
        emit ClaimToken(token, user, amount, orderId);
    }

    function depositToken(address token, uint256 amount)
        external
        override
        isNotContractCall
    {
        _chargeFee();
        transferTokenFrom(token, msg.sender, amount);
        emit DepositToken(token, msg.sender, amount);
    }

    function claimNFT(
        address nft,
        uint256 tokenId,
        uint256 orderId,
        bytes memory signature
    ) external override isNotContractCall {
        address user = msg.sender;
        _verifySignature(nft, user, tokenId, orderId, signature);
        require(_orderIds[orderId] == 0, "DUPLICATE_DEPOSIT");

        _orderIds[orderId] = 1;
        _chargeFee();
        transferNFTTo(nft, user, tokenId);
        emit ClaimNFT(nft, user, tokenId, orderId);
    }

    function depositNFT(address nft, uint256 tokenId)
        external
        override
        isNotContractCall
    {
        address user = msg.sender;
        _chargeFee();
        transferNFTFrom(nft, user, tokenId);
        emit DepositNFT(nft, user, tokenId);
    }

    function emergencyWithdraw(
        address token,
        address to,
        uint256 amount
    ) public onlyOwner {
        transferTokenTo(token, to, amount);
    }

    function keccak256Args(
        address tokenOrNFT,
        address user,
        uint256 amountOrTokenId,
        uint256 orderId
    ) public pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(tokenOrNFT, user, amountOrTokenId, orderId)
            );
    }

    function _verifySignature(
        address tokenOrNFT,
        address user,
        uint256 amountOrTokenId,
        uint256 orderId,
        bytes memory signature
    ) private view {
        bytes32 argsHash = keccak256Args(
            tokenOrNFT,
            user,
            amountOrTokenId,
            orderId
        );
        require(
            signer == Signature.getSigner(argsHash, signature),
            "VERIFY_FAILED"
        );
    }

    function _chargeFee() private {
        if (feeToken != address(0) && transactionFee > 0) {
            transferTokenFrom(feeToken, msg.sender, transactionFee);
        }
    }
}
