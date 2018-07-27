pragma solidity ^0.4.24;

/*import "./PlayerFundsManager.sol";*/
/** Open Zepplin Libraries */
/*import "zeppelin-solidity/contracts/math/SafeMath.sol";
import "zeppelin-solidity/contracts/lifecycle/Pausable.sol";*/
/** Note: Require in Remix*/
import "github.com/OpenZeppelin/zeppelin-solidity/contracts/math/SafeMath.sol"; 
import "github.com/OpenZeppelin/zeppelin-solidity/contracts/lifecycle/Pausable.sol"; 
 

/**
 * @title Smart contract for managing RockPaperScissor game
 *        Iteration#1: Simple contract for playing game
 */
/*contract RockPaperScissors is PlayerFundsManager {*/
contract RockPaperScissors is Pausable{
  using SafeMath for uint256;

  enum Moves {ROCK, PAPER, SCISSOR}
  Moves gameMove;
  

  struct GameParams{
    address player1; // Initiator of the game
    address player2; // Second player who have also joined the game
    Moves p1Move; // Player 1 move
    Moves p2Move; // Player 2 move
    uint p1Bet; // Player 1 bet amount
    uint p2Bet; // Player 2 bet amount
  }
  mapping(uint => GameParams) public games;  

  event LogCreateNewGame(address indexed playerAddress, uint betAmount );
  event LogJoinGame(address indexed playerAddress, uint gameID, uint betAmount );

  /**
   * @dev Function for creating new game
   * Function Code: [CG]
   */
  function createNewGame(uint gameID, uint betAmount) whenNotPaused public returns(bool success){
    require(betAmount >0, "[CG001] Invalid values" );
    require(fundsStore[msg.sender].amount >= betAmount, "[CG002] Should deposit funds before playing");
    require(games[gameID].p1Bet == 0, "[CG003] Game with same ID already used");
    
    fundsStore[msg.sender].amount -= betAmount;
    fundsStore[msg.sender].betAmount += betAmount;
    games[gameID].player1 = msg.sender;
    games[gameID].p1Bet = betAmount; // Suppoused to be 0
    emit LogCreateNewGame(msg.sender,betAmount);
    return true;
  }

  /**
   * @dev Function for joining game
   * Function Code: [JG]
   */
  function joinGame(uint gameID, uint betAmount) whenNotPaused public returns(bool success){
    require(betAmount >0, "[JG001] Invalid values" );
    require(fundsStore[msg.sender].amount >= betAmount, "[JG002] Should deposit funds before playing");
    require(games[gameID].player1 != address(0), "[JG003] Game does not exist");
    require(games[gameID].player1 != msg.sender, "[JG004] Invalid address");
    
    fundsStore[msg.sender].amount -= betAmount;
    fundsStore[msg.sender].betAmount += betAmount;

    games[gameID].player2 = msg.sender;
    games[gameID].p2Bet = betAmount; // Suppoused to be 0

    emit LogJoinGame(msg.sender,gameID,betAmount);    
    return true;
  }

  /**
   * @dev Procedure for submitting move
   * Function Code: [SM]
   */
  function submitMove(uint gameID,uint move) whenNotPaused public returns(bool success){
    require(games[gameID].player1 != address(0), "[SM001] Game does not exist");
    require(games[gameID].player2 != address(0), "[SM002] Game does not exist");
    require(move <= 3,"[SM003] Invalid move");
    
    if(games[gameID].player1 == msg.sender){
      require(games[gameID].p1Move == Moves(0),"[SM004] Your move is already submitted");
      games[gameID].p1Move = Moves(move);
    }else if(games[gameID].player2 == msg.sender){
      require(games[gameID].p2Move == Moves(0),"[SM004] Your move is already submitted");
      games[gameID].p2Move = Moves(move);
    }else{
      revert("[SM004] Invalid player. Please join the game first");
    }

    return true;
  }
  
  /**
   * @dev Procedure to check and declare checkWinner
   */
  function checkWinner(uint gameID) public returns(bool success){
    require(games[gameID].player1 != address(0), "Invalid Game ID");
    require(games[gameID].player1 == msg.sender || 
            games[gameID].player2 == msg.sender , "[CW001] Player is not part of the game");
    require(games[gameID].p1Move != Moves(0));
    require(games[gameID].p2Move != Moves(0));
    // Check moves now
    uint result = (uint(games[gameID].p1Move) + 1) % 3;
    if(games[gameID].p1Move == games[gameID].p2Move){
        // Invalid move
        games[gameID].p1Move = Moves(0);
        games[gameID].p2Move = Moves(0);
        return false;
    }else if(result == uint(games[gameID].p2Move)){
        // P2 won
        games[gameID].p1Move = Moves(0);
        games[gameID].p2Move = Moves(0);
        fundsStore[games[gameID].player2].amount += games[gameID].p1Bet;
        games[gameID].p1Bet = 0;
        return true;
    }else{
        // P1 won
        games[gameID].p1Move = Moves(0);
        games[gameID].p2Move = Moves(0);
        fundsStore[games[gameID].player1].amount += games[gameID].p2Bet;
        games[gameID].p2Bet = 0;
    }
     
    return true;
  }


  /** Following code can be converted into a another contract following Hub/Spoke model */
  /** Data Structure related to Funds */  
  struct Funds{
    // NOTE: Here betAmount + amount = Total Amount Deposited
    uint amount; // Amount deposited by the player which can is withdrawable
    uint betAmount; // Amount which is locked / beted on the 
    address contrAddress; // Address of the contract having amount parked
  }
  mapping(address => Funds) public fundsStore;
  /** End */
  event LogDepositFunds(address indexed playerAddress, uint amount );
  event LogWithdraw(address indexed playerAddress, uint amount, uint balance);
  /**
   * @dev Function for depositing funds to the contract
   * Function code: [DF]
   */
  function depositFunds() whenNotPaused public payable returns(bool success){
    require(msg.value > 0, "[DF001] Invalid Message Value"); 
    emit LogDepositFunds(msg.sender,msg.value);
    fundsStore[msg.sender].amount = msg.value;    
    return true;
  }

  /**
   * @dev Function for withdrawing amount from the account
   * Function Code: [WD]
   */
  function withdraw(uint amount) whenNotPaused public returns(bool success){
    require(fundsStore[msg.sender].amount > 0,"[WD001] No funds in the account");
    fundsStore[msg.sender].amount -= amount;
    emit LogWithdraw(msg.sender,amount,fundsStore[msg.sender].amount);
    msg.sender.transfer(amount);
    return true;
  }
  /** END */
}