
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../swap/libraries/TransferHelper.sol";

contract Token is ERC20, Ownable {
    constructor(
        string memory name,
        string memory symbol,
        uint256 supply
    ) ERC20(name, symbol) Ownable() {
        if (supply > 0) {
            _mint(msg.sender, supply);
        }
    }

    function getOwner() public view returns (address) {
        return owner();
    }

    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }

    function batchMint(address[] memory _to, uint256 _amount) public onlyOwner {
        for (uint256 i; i < _to.length; i++) {
            _mint(_to[i], _amount);
        }
    }

    function balancesOf(address[] memory owners)
        public
        view
        returns (uint256[] memory balances)
    {
        balances = new uint256[](owners.length);
        for (uint256 i; i < owners.length; i++) {
            balances[i] = balanceOf(owners[i]);
        }
    }

    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
    }

    function emergencyWithdraw(
        address token,
        address to,
        uint256 amount
    ) public onlyOwner {
        if (token == address(0)) {
            TransferHelper.safeTransferETH(to, amount);
        } else {
            TransferHelper.safeTransfer(token, to, amount);
        }
    }
}
