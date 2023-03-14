
pragma solidity ^0.8.4;

interface IWOKT {
    function deposit() external payable;

    function transfer(address to, uint256 value) external returns (bool);

    function withdraw(uint256) external;
}
