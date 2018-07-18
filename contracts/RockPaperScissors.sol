pragma solidity ^0.4.24;

import "./PlayerFundsManager.sol";
/** Open Zepplin Libraries */
import "zeppelin-solidity/contracts/math/SafeMath.sol";
import "zeppelin-solidity/contracts/lifecycle/Pausable.sol";

/**
 * @title Smart contract for managing RockPaperScissor game
 */
contract RockPaperScissors is Pausable {
  
  PlayerFundsManager public playerFundsManager = PlayerFundsManager(0);

  constructor() public{
  }

  /**
   * @dev Procedure for seting reference to PLayerFundsManager instance
   * TODO! Check if it is ethically right to change the PlayerFundsMgr instance
   *       Will it cause Danling reference ?
   */
  function setPlayerFundsManager(address playerFundsMgr) public whenNotPaused onlyOwner{

  }

}
