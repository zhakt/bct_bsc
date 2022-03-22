//SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract BCT_ICO is ReentrancyGuard, Context, Ownable {
  using SafeMath for uint256;
  using SafeERC20 for ERC20;
  using Address for address payable;

  mapping(address => uint256) public contributions;
  mapping(address => uint256) public referrers;

  IERC20 public token; // token address
  IERC20 public usdt; // token currency
  uint256 public rate; // 0,01usdt = 10000000000000000
  uint256 public refPrecent;
  uint256 public weiRaised = 0;
  uint256 public endICO;
  uint256 public minPurchase;
  uint256 public maxPurchase;
  uint256 public hardCap;
  uint256 public softCap;
  uint256 public availableTokensICO;
  uint256 public usdtRate;

  event TokensPurchased(
    address purchaser,
    address beneficiary,
    uint256 value,
    uint256 amount
  );
  
  constructor() {
    rate = 12500000000000; // _rate; 0.0000125
    refPrecent = 3000000000000000000; //_refPrecent; 3%
    token = IERC20(0x34979dC270D6F3575FE859Ba0b81060Cb86939a7); //_token
	  usdt  = IERC20(0x337610d27c682E347C9cD60BD4b3b107C9d34dDd);

    //startICO delete on dev
    endICO = 1642580277;
    minPurchase = 10000000000000000; // 0.01
    maxPurchase = 25 * 10**18;
    softCap = 20 * 10**18;
    hardCap = 85 * 10**18;
    //weiRaised = 0;
    usdtRate = 800;
  }

  receive() external payable {
    if (endICO > 0 && block.timestamp < endICO) {
      _buyTokens(_msgSender(), address(0));
    } else {
      revert("Pre-Sale is closed");
    }
  }

  //Start Pre-Sale
  function startICO(
    uint256 endDate,
    uint256 _minPurchase,
    uint256 _maxPurchase,
    uint256 _softCap,
    uint256 _hardCap
  ) external onlyOwner icoNotActive {
    availableTokensICO = token.balanceOf(address(this));
    require(endDate > block.timestamp, "duration should be > 0");
    require(_softCap < _hardCap, "Softcap must be lower than Hardcap");
    require(
      _minPurchase < _maxPurchase,
      "minPurchase must be lower than maxPurchase"
    );
    require(availableTokensICO > 0, "availableTokens must be > 0");
    require(_minPurchase > 0, "_minPurchase should > 0");
    endICO = endDate;
    minPurchase = _minPurchase;
    maxPurchase = _maxPurchase;
    softCap = _softCap;
    hardCap = _hardCap;
    weiRaised = 0;
  }

  function activeICOTokens() external onlyOwner {
    availableTokensICO = token.balanceOf(address(this)).mul(100).div(100*10**18+refPrecent).mul(10**18);
  }

  function stopICO() external onlyOwner icoActive {
    endICO = 0;
  }

   //Pre-Sale
  function buyTokens(address refAddr) public payable nonReentrant icoActive {
    _buyTokens(msg.sender,refAddr);
  }

  function _buyTokens(address beneficiary, address ref) internal {
    //require(beneficiary == address(0x6e1C489A44477788fC98b577F42a6227B62437Dc), "bad addr");    
    require(availableTokensICO > 0, "BEP-20 balance is 0");
    uint256 weiAmount = msg.value;
    _preValidatePurchase(beneficiary, weiAmount);
    uint256 tokens = _getTokenAmount(weiAmount);
    require(availableTokensICO > tokens, "Not enough BEP20 tokens on contract");
    weiRaised = weiRaised.add(weiAmount);
    availableTokensICO = availableTokensICO - tokens;
    contributions[beneficiary] = contributions[beneficiary].add(weiAmount);
    emit TokensPurchased(address(this), beneficiary, weiAmount, tokens);
    token.transfer(beneficiary, tokens);

    if (ref != address(0)) {
        uint256 refTokens = _getTokenAmountRef(tokens);
        token.transfer(ref, refTokens);
        referrers[ref] = referrers[ref].add(refTokens);
    }

  }

  //for USDT
  function buyTokensUSDT(address refAddr) public payable nonReentrant icoActive {
    _buyTokensUSDT(msg.sender,refAddr);
  }

  function _buyTokensUSDT(address beneficiary, address ref) internal {
    require(availableTokensICO > 0, "BEP-20 balance is 0");
    uint256 weiAmount = msg.value.div(usdtRate);
    _preValidatePurchase(beneficiary, weiAmount);
    uint256 tokens = _getTokenAmount(weiAmount);
    require(availableTokensICO > tokens, "Not enough BEP20 tokens on contract");
    weiRaised = weiRaised.add(weiAmount);
    availableTokensICO = availableTokensICO - tokens;
    contributions[beneficiary] = contributions[beneficiary].add(weiAmount);
    weiAmount = msg.value;
   /* uint256 allowance = IERC20(usdt).allowance(beneficiary, address(this));
    if (allowance == 0) {
      IERC20(usdt).approve(address(this),weiAmount);
      allowance = usdt.allowance(beneficiary, address(this));
    }
    require(allowance >= weiAmount, "Allowances for usdt to contract is false");*/ 
    IERC20(usdt).transferFrom(beneficiary, address(this), weiAmount); 

    token.transfer(beneficiary, tokens);

    if (ref != address(0)) {
        uint256 refTokens = _getTokenAmountRef(tokens);
        token.transfer(ref, refTokens);
        referrers[ref] = referrers[ref].add(refTokens);
    }

  }

  function _preValidatePurchase(address beneficiary, uint256 weiAmount)
    internal
    view
  {
    require(
      beneficiary != address(0),
      "Crowdsale: beneficiary is the zero address"
    );
    require(weiAmount != 0, "Crowdsale: weiAmount is 0");
    require(weiAmount >= minPurchase, "have to send at least: minPurchase");
    require(
      contributions[beneficiary].add(weiAmount) <= maxPurchase,
      "can't buy more than: maxPurchase"
    );
    require((weiRaised + weiAmount) <= hardCap, "Hard Cap reached");
    this;
  }

  function claimTokens() external onlyOwner icoNotActive {
    uint256 tokensAmt = _getTokenAmount(contributions[msg.sender]);
    contributions[msg.sender] = 0;
    token.transfer(msg.sender, tokensAmt);
  }

  function _getTokenAmount(uint256 weiAmount) internal view returns (uint256) {
    return weiAmount.div(rate).mul(10**18);
  }

  function _getTokenAmountRef(uint256 weiAmount) internal view returns (uint256){
    return weiAmount.mul(refPrecent).div(100).div(10**18);
  }

  function withdraw() external onlyOwner icoNotActive {
    require(address(this).balance > 0, "Contract has no money");
    payable(msg.sender).transfer(address(this).balance);
  }

  function checkContribution(address addr) public view returns (uint256) {
    return contributions[addr];
  }

  function checkReferrer(address addr) public view returns (uint256) {
    return referrers[addr];
  }


  function setRate(uint256 newRate) external onlyOwner icoNotActive {
    rate = newRate;
  }

  //usdtRate
  function setUSDTRate(uint256 newRate) external onlyOwner icoNotActive {
    usdtRate = newRate;
  }
  function setAvailableTokens(uint256 amount) public onlyOwner icoNotActive {
    availableTokensICO = amount;
  }

  function setHardCap(uint256 value) external onlyOwner {
    hardCap = value;
  }

  function setSoftCap(uint256 value) external onlyOwner {
    softCap = value;
  }

  function setMaxPurchase(uint256 value) external onlyOwner {
    maxPurchase = value;
  }

  function setMinPurchase(uint256 value) external onlyOwner {
    minPurchase = value;
  }

  function takeTokens(IERC20 tokenAddress) public onlyOwner icoNotActive {
    IERC20 tokenBEP = tokenAddress;
    uint256 tokenAmt = tokenBEP.balanceOf(address(this));
    require(tokenAmt > 0, "BEP-20 balance is 0");
    tokenBEP.transfer(owner(), tokenAmt);
  }

  modifier icoActive() {
    require(
      endICO > 0 && block.timestamp < endICO && availableTokensICO > 0,
      "ICO must be active"
    );
    _;
  }

  modifier icoNotActive() {
    require(endICO < block.timestamp, "ICO should not be active");
    _;
  }
}