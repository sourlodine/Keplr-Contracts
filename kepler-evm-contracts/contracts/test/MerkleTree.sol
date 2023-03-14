pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract MerkleTree {
    bytes32 public merkleRoot;

    uint256 public nextTokenId;

    mapping(address => bool) public claimed;

    constructor(bytes32 _merkleRoot) {
        merkleRoot = _merkleRoot;
    }

    function verify(bytes32[] calldata merkleProof, address user)
        external
        view
    {
        bool verified = MerkleProof.verify(
            merkleProof,
            merkleRoot,
            keccak256(abi.encodePacked(user))
        );
        require(verified, "invalid merkle proof");
    }
}
