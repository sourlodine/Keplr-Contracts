
pragma solidity ^0.8.4;

interface IUserClaim {
    enum Category {
        REFERRAL_REWARD,
        VOUNTEER_REWARD,
        CONTENT_CONTRIBUTION_REWARD,
        MARKETING_ACTIVIRY_REWARD
    }

    struct Claim {
        uint256 id;
        address claimer;
        uint8 category;
        address token;
        uint256 amount;
        uint256 time;
    }

    function keccak256ClaimArgs(
        address claimer,
        uint256 id,
        uint8 cateogry,
        address token,
        uint256 amount
    ) external pure returns (bytes32);

    function claim(
        uint256 id,
        uint8 cateogry,
        address token,
        uint256 amount,
        bytes memory signature
    ) external;

    function keccak256BatchClaimArgs(
        address claimer,
        uint256[] memory ids,
        uint8[] memory categories,
        address[] memory tokens,
        uint256[] memory amounts
    ) external pure returns (bytes32);

    function batchClaim(
        uint256[] memory ids,
        uint8[] memory categories,
        address[] memory tokens,
        uint256[] memory amounts,
        bytes memory signature
    ) external;

    function queryClaimCount() external view returns (uint256);

    function queryClaims(
        uint256 fromIndex,
        uint256 limit
    ) external view returns (Claim[] memory claims);
}
