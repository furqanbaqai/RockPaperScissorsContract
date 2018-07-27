pragma solidity ^0.4.24;

import "zeppelin-solidity/contracts/math/SafeMath.sol";
import "zeppelin-solidity/contracts/lifecycle/Pausable.sol";

/**
 * @title Smart Contract for managing playert funds
 */
contract PlayerFundsManager is Pausable {
  
  /**
   * This mapping will contain all memebers who are using this 
   * contract for accouting purpose
   */
  mapping(address=>bool) public members; 

  mapping(address=>uint) public gamerAccounts;

  constructor() public{
  }

  /**
   * @dev Procedure for depositing funds to the player account
   *      Assumption: Deposit can happen from the gamer contract only
   * @param playerAdd Address of the player who will deposit funds
   */
  function depositFunds(address playerAdd) payable whenNotPaused public{
    require(members[msg.sender],"[T001] Depositer contract address not found");
    require(playerAdd != address(0), "[T002] Invalid address");
    require(msg.value != 0, "[T003] Invalid values");
    // Assumption: I trust the sender contract as 
    // association is build during deployements
    gamerAccounts[playerAdd] += msg.value; 
  }

  /**
   * @dev Procedure for associating game contract with 
   * FundsManager
   * @param gameContractAdd Game Contract Address
   */
  function addMember(address gameContractAdd) onlyOwner public{
    require(gameContractAdd != address(0), "[T002] Invalid address");
    members[gameContractAdd] = true;
  }  

  /**
   * @dev Procedure to withdraw funds
   * @param value Value of the funds owner requires to pull out
   */
  function withdrawFunds(uint value) public{
    require(gamerAccounts[msg.sender] > 0, "[T004] No funds in the account");
    require(value > 0, "[T003] Invalid values");
    gamerAccounts[msg.sender] -= value;
    msg.sender.transfer(value);
  }
  
}
