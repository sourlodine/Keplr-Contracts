
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/common/ERC2981Upgradeable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "../common/Minable.sol";
import "./IPassport.sol";

contract Passport is
    ERC721EnumerableUpgradeable,
    ERC2981Upgradeable,
    OwnableUpgradeable,
    Minable,
    IPassport
{
    using Strings for uint256;
    string public baseURI;
    uint256 public nextTokenId;

    uint256 public override points;

    function initialize(
        string memory name_,
        string memory symbol_,
        string memory baseURI_,
        address minter_,
        uint256 points_
    ) public initializer {
        __Ownable_init();
        __ERC2981_init();
        __ERC721_init(name_, symbol_);
        baseURI = baseURI_;
        addMinter(msg.sender);
        addMinter(minter_);
        points = points_;
        nextTokenId = 1001;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(
            IERC165Upgradeable,
            ERC721EnumerableUpgradeable,
            ERC2981Upgradeable
        )
        returns (bool)
    {
        return
            interfaceId == type(IPassport).interfaceId ||
            ERC721EnumerableUpgradeable.supportsInterface(interfaceId) ||
            ERC721EnumerableUpgradeable.supportsInterface(interfaceId) ||
            ERC2981Upgradeable.supportsInterface(interfaceId);
    }

    function updateBaseURI(string memory val) public onlyOwner {
        baseURI = val;
    }

    function mint(address to) public override onlyMinter returns (uint256) {
        return _mintTo(to);
    }

    function _mintTo(address to) private returns (uint256) {
        uint256 tokenId = nextTokenId;
        nextTokenId++;
        _mint(to, tokenId);
        return tokenId;
    }

    function batchMint(address to, uint256 count) public onlyMinter {
        for (uint256 i; i < count; i++) {
            _mintTo(to);
        }
    }

    function burn(uint256 tokenId) public override {
        require(_isApprovedOrOwner(msg.sender, tokenId), "INVALID_ACCESS");
        _burn(tokenId);
        _resetTokenRoyalty(tokenId);
    }

    function tokensOfOwner(address owner)
        public
        view
        override
        returns (uint256[] memory tokenIds)
    {
        uint256 balance = balanceOf(owner);
        tokenIds = new uint256[](balance);
        for (uint256 i; i < balance; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(owner, i);
        }
    }

    function queryBaseURI() public view returns (string memory) {
        return baseURI;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721Upgradeable, IERC721MetadataUpgradeable)
        returns (string memory)
    {
        return string(abi.encodePacked(baseURI, tokenId.toString()));
    }

    function exists(uint256 tokenId) external view override returns (bool) {
        return _exists(tokenId);
    }

    function feeDenominator() external pure returns (uint96) {
        return _feeDenominator();
    }

    function setDefaultRoyalty(address receiver, uint96 feeNumerator)
        external
        onlyOwner
    {
        _setDefaultRoyalty(receiver, feeNumerator);
    }

    function deleteDefaultRoyalty() external onlyOwner {
        _deleteDefaultRoyalty();
    }

    function setTokenRoyalty(
        uint256 tokenId,
        address receiver,
        uint96 feeNumerator
    ) external {
        require(_isApprovedOrOwner(msg.sender, tokenId), "INVALID_ACCESS");
        _setTokenRoyalty(tokenId, receiver, feeNumerator);
    }

    function resetTokenRoyalty(uint256 tokenId) external {
        require(_isApprovedOrOwner(msg.sender, tokenId), "INVALID_ACCESS");
        _resetTokenRoyalty(tokenId);
    }
}
