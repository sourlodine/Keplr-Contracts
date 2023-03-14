
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/IERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/IERC721MetadataUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/interfaces/IERC2981Upgradeable.sol";

interface IPassport is
    IERC2981Upgradeable,
    IERC721MetadataUpgradeable,
    IERC721EnumerableUpgradeable
{
    function points() external view returns (uint256);

    function exists(uint256 tokenId) external view returns (bool);

    function burn(uint256 tokenId) external;

    function mint(address to) external returns (uint256);

    function tokensOfOwner(address owner)
        external
        view
        returns (uint256[] memory tokenIds);
}
