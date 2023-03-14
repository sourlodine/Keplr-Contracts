
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../swap/libraries/TransferHelper.sol";
import "../nft/IKeplerNFT.sol";
import "../tokens/IToken.sol";
import "../libraries/SafeDecimalMath.sol";
import "../libraries/Signature.sol";
import "../common/SafeAccess.sol";
import "./IBridge.sol";

contract Bridge is IBridge, OwnableUpgradeable, SafeAccess {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;
    using SafeDecimalMath for uint256;

    mapping(bytes32 => mapping(bytes32 => EnumerableSet.UintSet))
        private _userNFTs;

    mapping(bytes32 => mapping(bytes32 => uint256)) private _userTokens;

    EnumerableSet.AddressSet private _signers;
    EnumerableSet.AddressSet private _supportedNFTs;
    EnumerableSet.AddressSet private _supportedTokens;
    EnumerableSet.UintSet private _orderIds;

    uint256 public override tokenFeeRate;
    address public override nftFeeCurrency;
    uint256 public override nftFee;

    mapping(uint256 => TokenOrder) private _tokenApplyOrders;
    mapping(uint256 => TokenOrder) private _tokenClaimOrders;
    mapping(uint256 => NFTOrder) private _nftApplyOrders;
    mapping(uint256 => NFTOrder) private _nftClaimOrders;

    function initialize(
        address signer_,
        uint256 tokenFeeRate_,
        address nftFeeCurrency_,
        uint256 nftFee_
    ) public initializer {
        __Ownable_init();

        _signers.add(signer_);
        tokenFeeRate = tokenFeeRate_;
        nftFeeCurrency = nftFeeCurrency_;
        nftFee = nftFee_;
    }

    function updateTokenFeeRate(uint256 v) public onlyOwner {
        tokenFeeRate = v;
    }

    function updateNftFeeCurrency(address v) public onlyOwner {
        nftFeeCurrency = v;
    }

    function updateNftFee(uint256 v) public onlyOwner {
        nftFee = v;
    }

    function keccak256String(string memory val) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(val));
    }

    function keccak256ApplyTokenArgs(
        uint256 orderId,
        bytes32 applicant,
        bytes32 receipient,
        uint256 fromChainId,
        bytes32 fromNFT,
        uint256 amount,
        uint256 toChainId,
        uint256 deadline
    ) public pure override returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    orderId,
                    applicant,
                    receipient,
                    fromChainId,
                    fromNFT,
                    amount,
                    toChainId,
                    deadline
                )
            );
    }

    function applyToken(
        uint256 orderId,
        bytes32 applicant,
        bytes32 receipient,
        uint256 fromChainId,
        bytes32 fromToken,
        uint256 amount,
        uint256 toChainId,
        uint256 deadline,
        bytes memory signature
    ) external payable override isNotContractCall {
        require(deadline > block.timestamp, "EXPIRED");
        bytes32 argsHash = keccak256ApplyTokenArgs(
            orderId,
            applicant,
            receipient,
            fromChainId,
            fromToken,
            amount,
            toChainId,
            deadline
        );

        require(
            _signers.contains(Signature.getSigner(argsHash, signature)),
            "VERIFY_FAILED"
        );
        address token = bytes32ToAddress(fromToken);
        address to = bytes32ToAddress(applicant);
        require(_supportedTokens.contains(token), "UNSUPPORTED_TOKEN");
        require(to == msg.sender, "INVALID_APPLICANT");
        require(!_orderIds.contains(orderId), "ORDER_ID_EXISTS");
        _orderIds.add(orderId);

        uint256 fee = amount.multiplyDecimal(tokenFeeRate);
        _tansferFee(bytes32ToAddress(fromToken), fee);

        _userTokens[applicant][fromToken] += amount;
        _tokenApplyOrders[orderId] = TokenOrder(
            applicant,
            receipient,
            fromToken,
            amount
        );
        IToken(token).transferFrom(to, address(this), amount);
        emit ApplyToken(
            orderId,
            applicant,
            receipient,
            fromChainId,
            fromToken,
            amount,
            toChainId,
            fee
        );
    }

    function _tansferFee(address currency, uint256 fee) private {
        if (currency == address(0)) {
            require(msg.value >= fee, "INSUFFICIENT_FEE");
        } else {
            require(
                IERC20(currency).balanceOf(msg.sender) >= fee,
                "INSUFFICIENT_FEE_TOKEN_BALANCE"
            );
            require(
                IERC20(currency).allowance(msg.sender, address(this)) >= fee,
                "INSUFFICIENT_FEE_TOKEN_ALLOWANCE"
            );
            IERC20(currency).transferFrom(msg.sender, address(this), fee);
        }
    }

    function keccak256ApplyNFTArgs(
        uint256 orderId,
        bytes32 applicant,
        bytes32 receipient,
        uint256 fromChainId,
        bytes32 fromNFT,
        uint256[] memory fromTokenIds,
        uint256 toChainId,
        uint256 deadline
    ) public pure override returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    orderId,
                    applicant,
                    receipient,
                    fromChainId,
                    fromNFT,
                    fromTokenIds,
                    toChainId,
                    deadline
                )
            );
    }

    function applyNFT(
        uint256 orderId,
        bytes32 applicant,
        bytes32 receipient,
        uint256 fromChainId,
        bytes32 fromNFT,
        uint256[] memory fromTokenIds,
        uint256 toChainId,
        uint256 deadline,
        bytes memory signature
    ) external payable override isNotContractCall {
        require(deadline > block.timestamp, "EXPIRED");
        require(
            _signers.contains(
                Signature.getSigner(
                    keccak256ApplyNFTArgs(
                        orderId,
                        applicant,
                        receipient,
                        fromChainId,
                        fromNFT,
                        fromTokenIds,
                        toChainId,
                        deadline
                    ),
                    signature
                )
            ),
            "VERIFY_FAILED"
        );

        address nft = bytes32ToAddress(fromNFT);
        require(_supportedNFTs.contains(nft), "UNSUPPORTED_NFT");
        require(bytes32ToAddress(applicant) == msg.sender, "INVALID_APPLICANT");
        require(!_orderIds.contains(orderId), "ORDER_ID_EXISTS");
        _orderIds.add(orderId);
        _nftApplyOrders[orderId] = NFTOrder(
            applicant,
            receipient,
            fromNFT,
            fromTokenIds
        );

        _tansferFee(nftFeeCurrency, nftFee);

        for (uint256 i; i < fromTokenIds.length; i++) {
            uint256 tokenId = fromTokenIds[i];
            _userNFTs[applicant][fromNFT].add(tokenId);
            IKeplerNFT(nft).transferFrom(msg.sender, address(this), tokenId);
        }

        emit ApplyNFT(
            orderId,
            applicant,
            receipient,
            fromChainId,
            fromNFT,
            fromTokenIds,
            toChainId,
            nftFee
        );
    }

    function keccak256ClaimNFTArgs(
        uint256 orderId,
        bytes32 applicant,
        bytes32 receipient,
        uint256 toChainId,
        bytes32 toNFT,
        uint256[] memory tokenIds,
        uint256 deadline
    ) public pure override returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    orderId,
                    applicant,
                    receipient,
                    toChainId,
                    toNFT,
                    tokenIds,
                    deadline
                )
            );
    }

    function bytes32ToAddress(bytes32 _input) private pure returns (address) {
        return address(uint160(uint256(_input)));
    }

    function claimNFT(
        uint256 orderId,
        bytes32 applicant,
        bytes32 receipient,
        uint256 toChainId,
        bytes32 toNFT,
        uint256[] memory tokenIds,
        uint256 deadline,
        bytes memory signature
    ) external override isNotContractCall {
        require(deadline > block.timestamp, "EXPIRED");
        bytes32 argsHash = keccak256ClaimNFTArgs(
            orderId,
            applicant,
            receipient,
            toChainId,
            toNFT,
            tokenIds,
            deadline
        );

        require(
            _signers.contains(Signature.getSigner(argsHash, signature)),
            "VERIFY_FAILED"
        );

        address nft = bytes32ToAddress(toNFT);
        address to = bytes32ToAddress(receipient);
        require(msg.sender == to, "ACCESS_DENIED");
        require(!_orderIds.contains(orderId), "ORDER_ID_EXISTS");
        _orderIds.add(orderId);
        require(_supportedNFTs.contains(nft), "UNSUPPORTED_NFT");

        for (uint256 i; i < tokenIds.length; i++) {
            IKeplerNFT keplerNFT = IKeplerNFT(nft);
            uint256 tokenId = tokenIds[i];
            if (keplerNFT.exists(tokenId)) {
                require(
                    keplerNFT.ownerOf(tokenId) == address(this),
                    "INVALID_NFT_OWNER"
                );
                keplerNFT.transferFrom(address(this), to, tokenId);
            } else {
                keplerNFT.mintTo(to, tokenId);
            }
        }
        _nftClaimOrders[orderId] = NFTOrder(
            applicant,
            receipient,
            toNFT,
            tokenIds
        );
        emit ClaimNFT(
            orderId,
            applicant,
            receipient,
            toChainId,
            toNFT,
            tokenIds
        );
    }

    function keccak256ClaimTokenArgs(
        uint256 orderId,
        bytes32 applicant,
        bytes32 receipient,
        uint256 toChainId,
        bytes32 toToken,
        uint256 amount,
        uint256 deadline
    ) public pure override returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    orderId,
                    applicant,
                    receipient,
                    toChainId,
                    toToken,
                    amount,
                    deadline
                )
            );
    }

    function claimToken(
        uint256 orderId,
        bytes32 applicant,
        bytes32 receipient,
        uint256 toChainId,
        bytes32 toToken,
        uint256 amount,
        uint256 deadline,
        bytes memory signature
    ) external override isNotContractCall {
        require(deadline > block.timestamp, "EXPIRED");
        bytes32 argsHash = keccak256ClaimTokenArgs(
            orderId,
            applicant,
            receipient,
            toChainId,
            toToken,
            amount,
            deadline
        );
        require(
            _signers.contains(Signature.getSigner(argsHash, signature)),
            "VERIFY_FAILED"
        );
        address to = bytes32ToAddress(receipient);
        address token = bytes32ToAddress(toToken);
        require(msg.sender == to, "ACCESS_DENIED");
        require(!_orderIds.contains(orderId), "ORDER_ID_EXISTS");
        _orderIds.add(orderId);
        _tokenClaimOrders[orderId] = TokenOrder(
            applicant,
            receipient,
            toToken,
            amount
        );

        require(_supportedTokens.contains(token), "UNSUPPORTED_TOKEN");
        IToken(token).transfer(to, amount);
        emit ClaimToken(
            orderId,
            applicant,
            receipient,
            toChainId,
            toToken,
            amount
        );
    }

    function addSupportedNFTs(address[] memory items) public onlyOwner {
        for (uint256 i = 0; i < items.length; i++) {
            require(items[i] != address(0), "INVALID_NFT");
            _supportedNFTs.add(items[i]);
        }
    }

    function removeSupportedNFTs(address[] memory items) public onlyOwner {
        for (uint256 i = 0; i < items.length; i++) {
            _supportedNFTs.remove(items[i]);
        }
    }

    function getSupportedNFTs()
        external
        view
        override
        returns (address[] memory nfts)
    {
        nfts = new address[](_supportedNFTs.length());
        for (uint256 i; i < nfts.length; i++) {
            nfts[i] = _supportedNFTs.at(i);
        }
    }

    function addSupportedTokens(address[] memory items) public onlyOwner {
        for (uint256 i = 0; i < items.length; i++) {
            require(items[i] != address(0), "INVALID_TOKEN");
            _supportedTokens.add(items[i]);
        }
    }

    function removeSupportedTokens(address[] memory items) public onlyOwner {
        for (uint256 i = 0; i < items.length; i++) {
            _supportedTokens.remove(items[i]);
        }
    }

    function getSupportedTokens()
        external
        view
        override
        returns (address[] memory tokens)
    {
        tokens = new address[](_supportedTokens.length());
        for (uint256 i; i < tokens.length; i++) {
            tokens[i] = _supportedTokens.at(i);
        }
    }

    function getTokenApplyOrder(uint256 orderId)
        external
        view
        override
        returns (TokenOrder memory)
    {
        return _tokenApplyOrders[orderId];
    }

    function getTokenClaimOrder(uint256 orderId)
        external
        view
        override
        returns (TokenOrder memory)
    {
        return _tokenClaimOrders[orderId];
    }

    function getNFTApplyOrder(uint256 orderId)
        external
        view
        override
        returns (NFTOrder memory)
    {
        return _nftApplyOrders[orderId];
    }

    function getNFTClaimOrder(uint256 orderId)
        external
        view
        override
        returns (NFTOrder memory)
    {
        return _nftClaimOrders[orderId];
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
