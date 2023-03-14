
pragma solidity ^0.8.4;

import "hardhat/console.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../swap/libraries/TransferHelper.sol";
import "../libraries/SafeDecimalMath.sol";
import "../libraries/Signature.sol";
import "../common/SafeAccess.sol";
import "./IUserClaim.sol";

contract UserClaim is
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    OwnableUpgradeable,
    IUserClaim,
    SafeAccess
{
    using EnumerableSet for EnumerableSet.UintSet;

    address public signer;

    mapping(uint256 => Claim) private _claims;
    EnumerableSet.UintSet private _claimIds;

    function initialize(address signer_) public initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        signer = signer_;
    }

    function keccak256ClaimArgs(
        address claimer,
        uint256 id,
        uint8 category,
        address token,
        uint256 amount
    ) public pure override returns (bytes32) {
        return
            keccak256(abi.encodePacked(id, claimer, category, token, amount));
    }

    function keccak256BatchClaimArgs(
        address claimer,
        uint256[] memory ids,
        uint8[] memory categories,
        address[] memory tokens,
        uint256[] memory amounts
    ) public pure override returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(claimer, ids, categories, tokens, amounts)
            );
    }

    function batchClaim(
        uint256[] memory ids,
        uint8[] memory categories,
        address[] memory tokens,
        uint256[] memory amounts,
        bytes memory signature
    ) external override nonReentrant whenNotPaused isNotContractCall {
        address claimer = msg.sender;
        require(ids.length == categories.length, "INVALID_PARAMETERS");
        require(ids.length == tokens.length, "INVALID_PARAMETERS");
        require(ids.length == amounts.length, "INVALID_PARAMETERS");

        bytes32 argsHash = keccak256BatchClaimArgs(
            claimer,
            ids,
            categories,
            tokens,
            amounts
        );
        require(
            signer == Signature.getSigner(argsHash, signature),
            "VERIFY_FAILED"
        );

        for (uint256 i; i < ids.length; i++) {
            _claim(claimer, ids[i], categories[i], tokens[i], amounts[i]);
        }
    }

    function _claim(
        address claimer,
        uint256 id,
        uint8 category,
        address token,
        uint256 amount
    ) private {
        require(
            IERC20(token).balanceOf(address(this)) >= amount,
            "INSUFFICIENT_VAULT_BALANCE"
        );
        require(!_claimIds.contains(id), "CLAIM_ID_EXISTS");
        require(
            category <= uint8(Category.MARKETING_ACTIVIRY_REWARD),
            "INVALID_CATEGORY"
        );
        _claimIds.add(id);

        _claims[id] = Claim({
            id: id,
            claimer: claimer,
            category: category,
            token: token,
            amount: amount,
            time: block.timestamp
        });

        IERC20(token).transfer(claimer, amount);
    }

    function claim(
        uint256 id,
        uint8 category,
        address token,
        uint256 amount,
        bytes memory signature
    ) external override nonReentrant whenNotPaused isNotContractCall {
        address claimer = msg.sender;
        bytes32 argsHash = keccak256ClaimArgs(
            claimer,
            id,
            category,
            token,
            amount
        );
        require(
            signer == Signature.getSigner(argsHash, signature),
            "VERIFY_FAILED"
        );

        _claim(claimer, id, category, token, amount);
    }

    function queryClaims(uint256 fromIndex, uint256 limit)
        external
        view
        override
        returns (Claim[] memory claims)
    {
        uint256 length = _claimIds.length();
        limit = fromIndex < length
            ? SafeDecimalMath.min(limit, length - fromIndex)
            : 0;

        claims = new Claim[](limit);
        for (uint256 i; i < limit; i++) {
            claims[i] = _claims[_claimIds.at(fromIndex + i)];
        }
    }

    function queryClaimCount() external view override returns (uint256) {
        return _claimIds.length();
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
