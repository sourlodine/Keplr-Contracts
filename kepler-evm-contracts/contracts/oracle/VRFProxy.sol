pragma solidity ^0.8.4;

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";
import "./VRFConsumer.sol";

contract VRFProxy is VRFConsumerBaseV2, ConfirmedOwner {
    event RequestFulfilled(uint256 requestId, uint256[] randomWords);

    mapping(uint256 => address) private _requests;
    address public _coordinator;

    constructor(address coordinator)
        VRFConsumerBaseV2(coordinator)
        ConfirmedOwner(msg.sender)
    {
        _coordinator = coordinator;
    }

    function updateCoordinator(address coordinator) external {
        require(msg.sender == owner(), "INVALID_ACCESS");
        _coordinator = coordinator;
    }

    function requestRandomWords(
        bytes32 keyHash,
        uint64 subscriptionId,
        uint16 requestConfirmations,
        uint32 callbackGasLimit,
        address consumer,
        uint32 numWords
    ) external onlyOwner {
        uint256 requestId = VRFCoordinatorV2Interface(_coordinator)
            .requestRandomWords(
                keyHash,
                subscriptionId,
                requestConfirmations,
                callbackGasLimit,
                numWords
            );
        _requests[requestId] = consumer;
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords)
        internal
        override
    {
        address consumer = _requests[requestId];
        require(consumer != address(0), "request not found");
        VRFConsumer(consumer).consumeRandomWords(randomWords);
    }
}
