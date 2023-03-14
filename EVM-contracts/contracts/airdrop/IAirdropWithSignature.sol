
pragma solidity ^0.8.4;

interface IAirdropWithSignature {
    function claim(bytes memory signature) external;

    function isClaimed(address claimer) external view returns (bool);

    function queryClaimers() external view returns (address[] memory claimers);

    function queryVariables()
        external
        view
        returns (
            address rewardToken,
            uint256 rewardAmount,
            uint256 totalRewardAmount,
            uint256 totalClaimedRewardAmount,
            uint256 startCliamTime,
            uint256 endClaimTime
        );
}
