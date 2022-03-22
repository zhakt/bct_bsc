// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";

contract BCT_AirDrop is Context, Ownable {
    IERC20 public token; // token address

    constructor() {
        token = IERC20(0x34979dC270D6F3575FE859Ba0b81060Cb86939a7); //_token
    }

    function sendTokensToList(address[] calldata _addr,uint256 amount) public onlyOwner {
        require(token.balanceOf(address(this)) >= amount, "Contract has no tokens");
        for (uint i = 0; i < _addr.length; ++i){
            require(token.balanceOf(address(this)) >= amount, "Contract has no tokens");
            token.transfer(_addr[i], amount);
        }
    }

    function takeTokens() public onlyOwner {
        uint256 tokenAmt = token.balanceOf(address(this));
        require(tokenAmt > 0, "BEP-20 balance is 0");
        token.transfer(owner(), tokenAmt);
    }

}