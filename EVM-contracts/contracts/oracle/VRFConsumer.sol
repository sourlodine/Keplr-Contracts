pragma solidity ^0.8.4;

interface VRFConsumer {
    function consumeRandomWords(uint256[] memory randomWords) external;
}
