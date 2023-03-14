
pragma solidity ^0.8.4;

import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../swap/libraries/TransferHelper.sol";
import "../libraries/Signature.sol";
import "../common/SafeAccess.sol";
import "./IAirdropWithSignature.sol";

contract AirdropWithSignature is
    ReentrancyGuard,
    Ownable,
    SafeAccess,
    IAirdropWithSignature
{
    using EnumerableSet for EnumerableSet.AddressSet;
    EnumerableSet.AddressSet private _claimers;

    address private _signer;
    address private _rewardToken;
    uint256 private _rewardAmount;
    uint256 private _totalRewardAmount;
    uint256 public _totalClaimedRewardAmount;
    uint256 private _startCliamTime;
    uint256 private _endClaimTime;

    constructor(
        address rewardToken,
        uint256 rewardAmount,
        uint256 totalRewardAmount,
        uint256 startCliamTime,
        uint256 endClaimTime,
        address signer
    ) ReentrancyGuard() Ownable() {
        _rewardToken = rewardToken;
        _rewardAmount = rewardAmount;
        _signer = signer;
        _totalRewardAmount = totalRewardAmount;
        _totalClaimedRewardAmount = 0;
        _startCliamTime = startCliamTime;
        _endClaimTime = endClaimTime;
    }

    function updateClaimTime(uint256 startCliamTime, uint256 endClaimTime)
        public
        onlyOwner
    {
        _startCliamTime = startCliamTime;
        _endClaimTime = endClaimTime;
    }

    function updateSigner(address value) public onlyOwner {
        _signer = value;
    }

    function updateTotalRewardAmount(uint256 value) public onlyOwner {
        _totalRewardAmount = value;
    }

    function queryVariables()
        public
        view
        override
        returns (
            address rewardToken,
            uint256 rewardAmount,
            uint256 totalRewardAmount,
            uint256 totalClaimedRewardAmount,
            uint256 startCliamTime,
            uint256 endClaimTime
        )
    {
        return (
            _rewardToken,
            _rewardAmount,
            _totalRewardAmount,
            _totalClaimedRewardAmount,
            _startCliamTime,
            _endClaimTime
        );
    }

    function _verifySignature(address user, bytes memory signature)
        private
        view
    {
        require(
            Signature.getSigner(
                keccak256(abi.encodePacked(address(this), user)),
                signature
            ) == _signer,
            "VERIFY_FAILED"
        );
    }

    function claim(bytes memory signature)
        external
        override
        nonReentrant
        isNotContractCall
    {
        address claimer = msg.sender;
        require(_startCliamTime <= block.timestamp, "CLIAM_NOT_STARTED");
        require(_endClaimTime >= block.timestamp, "CLAIM_FINISHED");
        require(!_claimers.contains(claimer), "DUPLICATE_CLAIM");
        require(
            _totalClaimedRewardAmount + _rewardAmount <= _totalRewardAmount,
            "CLAIM_FINISHED"
        );
        _verifySignature(claimer, signature);
        require(
            IERC20(_rewardToken).balanceOf(address(this)) >= _rewardAmount,
            "INSUFFICIENT_VAULT_BALANCE"
        );
        _claimers.add(claimer);
        _totalClaimedRewardAmount += _rewardAmount;
        IERC20(_rewardToken).transfer(claimer, _rewardAmount);
    }

    function isClaimed(address claimer) external view override returns (bool) {
        return _claimers.contains(claimer);
    }

    function queryClaimers()
        external
        view
        override
        returns (address[] memory claimers)
    {
        claimers = new address[](_claimers.length());
        for (uint256 i; i < claimers.length; i++) {
            claimers[i] = _claimers.at(i);
        }
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
