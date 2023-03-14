pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract PresaleLuckyDraw is OwnableUpgradeable {
    address[] public participants;
    address[] public luckyAddresses;
    address public vrfProxy;
    uint256 public constant LUCKY_COUNT = 100;
    uint256 public constant CANDIDATE_COUNT = 2000;

    event RandomWordsReceived(uint256[] randomWords);

    function initialize(address vrfProxy_) public initializer {
        __Ownable_init();
        vrfProxy = vrfProxy_;
    }

    function queryPaticipantCount() public view returns (uint256) {
        return participants.length;
    }

    function queryLuckyAddresses() public view returns (address[] memory) {
        return luckyAddresses;
    }

    function updateVrfProxy(address val) external onlyOwner {
        vrfProxy = val;
    }

    function importParticipants(address[] memory values) external onlyOwner {
        for (uint256 i; i < values.length; i++) {
            participants.push(values[i]);
        }
    }

    function clearParticipants() external onlyOwner {
        participants = new address[](0);
    }

    function clearLuckyAddresses() external onlyOwner {
        luckyAddresses = new address[](0);
    }

    function consumeRandomWords(uint256[] memory randomWords) external {
        require(randomWords.length > 0, "INVALID_RANDOM_WORDS");
        require(
            msg.sender == vrfProxy || msg.sender == owner(),
            "INVALID_ACCESS"
        );
        require(
            participants.length >= CANDIDATE_COUNT,
            "INSUFFICIENT_CANDIDATES"
        );
        draw(randomWords[0]);
        emit RandomWordsReceived(randomWords);
    }

    function draw(uint256 randomNumber) private {
        uint256 drawCount = 10;
        uint256 luckyCount = luckyAddresses.length;
        for (uint256 i; i < drawCount; i++) {
            uint256 length = CANDIDATE_COUNT - luckyCount - i - 1;
            uint256 index = uint256(
                keccak256(abi.encodePacked(randomNumber + i * 100))
            ) % length;
            address luckyAddress = participants[index];
            luckyAddresses.push(luckyAddress);
            participants[index] = participants[length - i];
            participants[length - i] = luckyAddress;
        }
    }
}
