
pragma solidity ^0.8.4;

interface IAirdrop {
    function claim(bytes32[] calldata merkleProof) external;

    function isClaimed(address claimer) external view returns (bool);

    function queryClaimers() external view returns (address[] memory claimers);

    function queryVariables()
        external
        view
        returns (
            bytes32 merkleRoot,
            address rewardToken,
            uint256 rewardAmount,
            uint256 totalRewardAmount,
            uint256 totalClaimedRewardAmount,
            uint256 startCliamTime,
            uint256 endClaimTime
        );
}
