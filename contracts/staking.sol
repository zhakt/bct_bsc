//SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract BCT_Staking is ReentrancyGuard, Context, Ownable {
  using SafeMath for uint256;
  using SafeERC20 for ERC20;
  using Address for address payable;

  IERC20 public token; // token address
  // дата окончания
  uint256 public endPeriod;
  // дата начала
  // address - amount вклад
  mapping(address => uint256) public contributors;
  // address - day - amount выплата
  // address - список адресов
  address[] private _contributors;
  uint8 public Precent;

  constructor() {
    token = IERC20(0x34979dC270D6F3575FE859Ba0b81060Cb86939a7); //_token
    endPeriod = 1647304467;
    Precent = 36;
  }

  function sendTokens() public payable nonReentrant contractActive { //address refAddr
    //_sendTokens(msg.sender,refAddr);
    _sendTokens(msg.sender);
  }

  function _sendTokens(address beneficiary) internal { //, address ref
    uint256 allowance = token.allowance(beneficiary, address(this));
    uint256 weiAmount = msg.value;
    require(allowance >= weiAmount && weiAmount > 0, "Allowances for bct to contract is false"); 
    token.transferFrom(beneficiary, address(this), weiAmount); 
    contributors[beneficiary] = contributors[beneficiary].add(weiAmount);
    if (contributors[beneficiary] == weiAmount) {
      _contributors.push(beneficiary);
    }
    /*if (ref != address(0)) {
        uint256 refTokens = _getTokenAmountRef(tokens);
        token.transfer(ref, refTokens);
        referrers[ref] = referrers[ref].add(refTokens);
    }*/

  }

  function takeTokens() public onlyOwner {
    uint256 tokenAmt = token.balanceOf(address(this));
    require(tokenAmt > 0, "BEP-20 balance is 0");
    token.transfer(owner(), tokenAmt);
  }

  modifier contractActive() {
    require(
      endPeriod > 0 && block.timestamp < endPeriod,
      "Contract must be active"
    );
    _;
  }
}