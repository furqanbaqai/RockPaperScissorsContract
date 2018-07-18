pragma solidity ^0.4.24;

import "zeppelin-solidity/contracts/math/SafeMath.sol";
import "zeppelin-solidity/contracts/lifecycle/Pausable.sol";

/**
 * @title Smart Contract for managing playert funds
 */
contract PlayerFundsManager is Pausable {
   
  constructor() public{
  }

  /**
   * @dev Procedure for depositing funds to the player account
   * @param playerAdd Address of the player who will deposit funds
   */
  function depositFunds(address playerAdd) payable whenNotPaused onlyOwner public{

  }

  /**
   * @dev Procedure to withdraw funds
   * @param value Value of the funds owner requires to pull out
   */
  function withdrawFunds(uint value) public{

  }
  
}
