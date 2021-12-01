//SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
//import "@openzeppelin/contracts/interfaces/IERC20.sol";

interface IERC20 {

    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}



contract BCT_ICO is ReentrancyGuard, Context, Ownable {
  using SafeMath for uint256;

  mapping(address => uint256) public contributions;
  mapping(address => bool) public whitelists;
  address[] private whiteWallets;

  IERC20 public token; // token address
  IERC20 public usdt; // token currency
  address payable public usdtWallet; // wallet for usdt
  address payable public payWallet; // wallet from who were minus tokens
  uint256 public rate; // 0,01usdt = 10000000000000000
  uint256 public tokenDecimals;
  uint256 public refPrecent;
  uint256 public weiRaised;
  uint256 public endICO;
  uint256 public minPurchase;
  uint256 public maxPurchase;
  uint256 public hardCap;
  uint256 public softCap;
  uint256 public availableTokensICO;

  event TokensPurchased(
    address purchaser,
    address beneficiary,
    uint256 value,
    uint256 amount
  );
  

  constructor(
    uint256 _rate,
    uint256 _refPrecent,
    address payable _wallet,
    address payable _usdtwallet,
    IERC20 _token,
    IERC20 _usdt
  ) {
    require(_rate > 0, "Pre-Sale: rate is 0");
    require(_wallet != address(0), "Pre-Sale: wallet is the zero address");
    require(_usdtwallet != address(0), "Pre-Sale: wallet is the zero address");
    require(
      address(_token) != address(0),
      "Pre-Sale: token is the zero address"
    );
	require(
      address(_usdt) != address(0),
      "Pre-Sale: usdt is the zero address"
    );

    rate = _rate;
    refPrecent = _refPrecent;
    payWallet = _wallet;
    usdtWallet = _usdtwallet;
    token = _token;
	usdt = _usdt;
  }

  receive() external payable {
    if (endICO > 0 && block.timestamp < endICO) {
      _buyTokens(_msgSender());
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
    //availableTokensICO = token.balanceOf(address(this));
    availableTokensICO = token.balanceOf(payWallet);
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

  function stopICO() external onlyOwner icoActive {
    endICO = 0;
  }

  function clearWhitelists() external onlyOwner {
    for (uint8 i = 0; i < whiteWallets.length; i++) {
      whitelists[whiteWallets[i]] = false;
    }
    delete whiteWallets;
  }

  //Pre-Sale
  function buyTokens() public payable nonReentrant icoActive {
    require(whitelists[msg.sender] == true, "Wallet is not whitelisted");
    _buyTokens(msg.sender);
  }

  function addWhitelist(address wallet) external onlyOwner {
    whitelists[wallet] = true;
    whiteWallets.push(wallet);
  }

  function _buyTokens(address beneficiary) internal {
    uint256 weiAmount = msg.value;
    _preValidatePurchase(beneficiary, weiAmount);
    uint256 tokens = _getTokenAmount(weiAmount);
    weiRaised = weiRaised.add(weiAmount);
    availableTokensICO = availableTokensICO - tokens;
    contributions[beneficiary] = contributions[beneficiary].add(weiAmount);
    emit TokensPurchased(_msgSender(), beneficiary, weiAmount, tokens);
   // usdt.transfer(usdtWallet,weiAmount); // кому, сколько - кто это кто запустил функцию
   // token.transferFrom(payWallet,beneficiary,tokens);
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

  function claimTokens() external icoNotActive {
    require(whitelists[msg.sender] == true, "Wallet is not whitelisted");

    uint256 tokensAmt = _getTokenAmount(contributions[msg.sender]);
    contributions[msg.sender] = 0;
    token.transfer(msg.sender, tokensAmt);
  }

  function _getTokenAmount(uint256 weiAmount) internal view returns (uint256) {
    return weiAmount.mul(rate);
  }

  function withdraw() external onlyOwner icoNotActive {
    require(address(this).balance > 0, "Contract has no money");
    payWallet.transfer(address(this).balance);
  }

  function checkContribution(address addr) public view returns (uint256) {
    return contributions[addr];
  }

  function setRate(uint256 newRate) external onlyOwner icoNotActive {
    rate = newRate;
  }

  function setAvailableTokens(uint256 amount) public onlyOwner icoNotActive {
    availableTokensICO = amount;
  }

  function setWalletReceiver(address payable newWallet) external onlyOwner {
    payWallet = newWallet;
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
    tokenBEP.transfer(payWallet, tokenAmt);
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