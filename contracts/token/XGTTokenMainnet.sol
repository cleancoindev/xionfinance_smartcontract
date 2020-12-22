pragma solidity ^0.5.16;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Mintable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Burnable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "@openzeppelin/upgrades/contracts/ownership/Ownable.sol";
import "../interfaces/IBridgeContract.sol";
import "../interfaces/IXGTToken.sol";

contract XGTTokenMainnet is Initializable, OpenZeppelinUpgradesOwnable, ERC20Detailed, ERC20Mintable, ERC20Burnable {
    using SafeMath for uint256;

    address public xDaiContract;
    IBridgeContract public bridge;

    function initialize(address _xDaiContract, address _bridge) public initializer {
        ERC20Detailed.initialize("XionGlobal Token", "XGT", 18);
        xDaiContract = _xDaiContract;
        bridge = IBridgeContract(_bridge);
    }

    function transferredToMainnet(address _user, uint256 _amount) external {
        require(msg.sender == address(bridge), "XGT-NOT-BRIDGE");
        require(bridge.messageSender() == xDaiContract, "XGT-NOT-XDAI-CONTRACT");
        _mint(_user, _amount);
    }

    function transferToXDai(uint256 _amount) external {
        _burn(msg.sender, _amount);
        bytes4 _methodSelector = IXGTToken(address(0)).transferredToXDai.selector;
        bytes memory data = abi.encodeWithSelector(_methodSelector, msg.sender, _amount);
        bridge.requireToPassMessage(xDaiContract,data,300000);
    }
}