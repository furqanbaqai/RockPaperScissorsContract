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

  enum Moves {INVALID,ROCK, PAPER, SCISSOR}
  Moves gameMove;
  

  struct GameParams{
    address player1; // Initiator of the game
    address player2; // Second player who have also joined the game
    bytes32 p1MoveHash; // Player 1 move hash
    bytes32 p2MoveHash; // Player 2 move hash
    Moves p1MoveID;
    Moves p2MoveID;
    uint p1Bet; // Player 1 bet amount
    uint p2Bet; // Player 2 bet amount
    address lastWinner;
  }
  mapping(uint => GameParams) public games;  

  event LogCreateNewGame(address indexed playerAddress, uint betAmount, uint gameID );
  event LogJoinGame(address indexed playerAddress, uint gameID, uint betAmount );
  event LogSubmitMove(address indexed playerAddress, uint _gameID, bytes32 _moveHash );
  event LogWinner(address indexed calleAddress, uint _gameID, address winner, uint wonAmount, uint amountReturned);

  /**
   * @dev Function for creating new game
   * Function Code: [CG]
   */
  function createNewGame(uint _gameID, uint _betAmount) whenNotPaused public returns(bool success){
    require(_betAmount >0, "[CG001] Invalid values" );
    require(fundsStore[msg.sender].amount >= _betAmount, "[CG002] Should deposit funds before playing");
    require(games[_gameID].p1Bet == 0, "[CG003] Game with same ID already used");
    
    fundsStore[msg.sender].amount = fundsStore[msg.sender].amount.sub(_betAmount); // Subtracting bet amount from players amount
    fundsStore[msg.sender].betAmount = fundsStore[msg.sender].betAmount.add(_betAmount); // Adding players amount to bet amount. This amount will be used for betting
    games[_gameID].player1 = msg.sender;
    games[_gameID].p1Bet = _betAmount; // Suppoused to be 0
    emit LogCreateNewGame(msg.sender,_betAmount, _gameID);
    return true;
  }

  /**
   * @dev Function for joining game
   * Function Code: [JG]
   * This function will be used in two ways:
   * * New player will be able to join existing game started by player 1.
   * * Existing player will be able to Top-Up their account
   */
  function joinGame(uint _gameID, uint _betAmount) whenNotPaused public returns(bool success){
    require(_betAmount >0, "[JG001] Invalid values" );
    require(fundsStore[msg.sender].amount >= _betAmount, "[JG002] Should deposit funds before playing");
    require(games[_gameID].player1 != address(0), "[JG003] Game does not exist");
    if(games[_gameID].player1 != msg.sender && games[_gameID].player2 != address(0)){
        // Player is toping up the account for existing game
        require(games[_gameID].player2 == msg.sender, "[JG005] Invalid address");
    }
    fundsStore[msg.sender].amount = fundsStore[msg.sender].amount.sub(_betAmount);
    fundsStore[msg.sender].betAmount = fundsStore[msg.sender].betAmount.add(_betAmount);
    if(games[_gameID].player1 != msg.sender){
        games[_gameID].player2 = msg.sender;
        games[_gameID].p2Bet = games[_gameID].p2Bet.add(_betAmount); // Suppoused to be 0  
    }else{
        games[_gameID].p1Bet = games[_gameID].p1Bet.add(_betAmount); 
    } 
    emit LogJoinGame(msg.sender,_gameID,_betAmount);    
    return true;
  }

  /**
   * @dev Procedure for submitting move to an existing Game. 
   * Function Code: [SM]
   * @param _gameID Game ID for which move is geting submitted. Player should either create a game OR 
   * JOIN a game before calling this procedure.
   */
  function submitMove(uint _gameID,bytes32 _moveHash) whenNotPaused public returns(bool success){
    /* Both players should be enrolled */
    require(games[_gameID].player1 != address(0), "[SM001] Game does not exist");
    require(games[_gameID].player2 != address(0), "[SM002] Game does not exist");
    
    require(_moveHash != bytes32(0),"[SM003] Invalid move hash");
    
    if(games[_gameID].player1 == msg.sender){
      require(games[_gameID].p1MoveID == Moves(0),"[SM004] Your move is already submitted");
      require(games[_gameID].p1MoveHash == bytes32(0), "[SM004] Your move is already submitted");
      require(games[_gameID].p1Bet > 0, "Please bet some amount");
      games[_gameID].p1MoveHash = _moveHash;
    }else if(games[_gameID].player2 == msg.sender){
      require(games[_gameID].p2MoveID == Moves(0),"[SM004] Your move is already submitted");
      require(games[_gameID].p2MoveHash == bytes32(0), "[SM004] Your move is already submitted");
      require(games[_gameID].p2Bet > 0, "Please bet some amount");
      games[_gameID].p2MoveHash = _moveHash;
    }else{
      revert("[SM004] Invalid player. Please join the game first");
    }
    emit LogSubmitMove(msg.sender,_gameID, _moveHash);
    return true;
  }
  
  /**
   * @dev Procedure to check and declare checkWinner
   *      In-case a player is winner, his bet amount will
   *      go to the player1 account. This amount will not be
   *      betted.
   *      This procedure can be triggered by any player playing the game
   * @param _gameID Game ID to check winner for. 
   */
  function checkWinner(uint _gameID) public returns(bool success){
    require(games[_gameID].player1 != address(0), "Invalid Game ID");
    require(games[_gameID].player1 == msg.sender || 
            games[_gameID].player2 == msg.sender , "[CW001] Player is not part of the game");
    /* Move Hash should be provided */
    require(games[_gameID].p1MoveHash != bytes32(0));
    require(games[_gameID].p2MoveHash != bytes32(0));
    
    /* Moves should be revealed by each party */
    require(games[_gameID].p1MoveID != Moves(0));
    require(games[_gameID].p2MoveID != Moves(0));
    
    // Check moves now
    uint wonAmount;
    uint amountReturned;
    uint result = uint(games[_gameID].p1MoveID) % 3;
    if(games[_gameID].p1MoveID == games[_gameID].p2MoveID){
        // No winner
        games[_gameID].p1MoveID = Moves(0);
        games[_gameID].p2MoveID = Moves(0);
        games[_gameID].p1MoveHash = bytes32(0);
        games[_gameID].p1MoveHash = bytes32(0);
        return false;
    }else if(result == uint(games[_gameID].p1MoveID)){
        // P1 won
        games[_gameID].p1MoveID = Moves(0);
        games[_gameID].p2MoveID = Moves(0);
        games[_gameID].p1MoveHash = bytes32(0);
        games[_gameID].p1MoveHash = bytes32(0);
        fundsStore[games[_gameID].player1].amount = fundsStore[games[_gameID].player1].amount.add(games[_gameID].p2Bet.add(games[_gameID].p1Bet));
        wonAmount = games[_gameID].p2Bet;
        amountReturned = games[_gameID].p1Bet.add(games[_gameID].p2Bet);
        games[_gameID].p1Bet = 0;
        games[_gameID].p2Bet = 0;
        games[_gameID].lastWinner = games[_gameID].player1;
        emit LogWinner(msg.sender, _gameID, games[_gameID].player1, wonAmount, amountReturned);
    }else{
        // P2 won
        games[_gameID].p1MoveID = Moves(0);
        games[_gameID].p2MoveID = Moves(0);
        games[_gameID].p1MoveHash = bytes32(0);
        games[_gameID].p1MoveHash = bytes32(0);
        // Amount bet by P1 will go to P2 and amount bet by P2 will be returned to the P2 account
        fundsStore[games[_gameID].player2].amount = games[_gameID].p1Bet.add(games[_gameID].p2Bet);
        // fundsStore[games[_gameID].player2].amount = fundsStore[games[_gameID].player2].amount.add(games[_gameID].p2Bet);
        wonAmount = games[_gameID].p1Bet;
        amountReturned = games[_gameID].p1Bet.add(games[_gameID].p2Bet);
        games[_gameID].p1Bet = 0;
        games[_gameID].p2Bet = 0;
        games[_gameID].lastWinner = games[_gameID].player2;
        emit LogWinner(msg.sender, _gameID, games[_gameID].player1, wonAmount, amountReturned);
    }
    
    return true;
  }
  
  /**
   * @dev Procedure for revealing the move. Idea behind this Procedure is that the move
   * will remain encoded and any player can reveal the move to validate winner.
   * Function Code: RM
   * TODO! Player who have not revealed his move, should be given some time to reveal. Otherwise
   * his bet amount should be transfered to the other player
   * @param _secret Secret / Password used for hashing the move
   * @param _gameID ID of the game for which secret is geting revealed
   * 
   **/
  function revealMove(bytes32 _secret, uint _gameID) public returns(bool success){
      require(games[_gameID].player1 == msg.sender || games[_gameID].player2 == msg.sender, "[RM001]: Invalid game ID");
      require(games[_gameID].p1MoveHash != bytes32(0), "[RM002]: Please submit your move first");
      require(games[_gameID].p2MoveHash != bytes32(0), "[RM002]: Please submit your move first");
      /* Not allowed to call this function again if move is already revealed */
      if(games[_gameID].player1 == msg.sender){ // Player 1 is calling this function
          require(games[_gameID].p1MoveID == Moves(0), "[RM003] Not allowed to reveal again");
          games[_gameID].p1MoveID = this.hashToMoveConverter(_secret,_gameID,games[_gameID].p1MoveHash);
      }else if(games[_gameID].player2 == msg.sender){ // Player2 is calling this function
        require(games[_gameID].p2MoveID == Moves(0), "[RM003] Not allowed to reveal again");    
        games[_gameID].p2MoveID = this.hashToMoveConverter(_secret,_gameID,games[_gameID].p2MoveHash);
      }
      return true;
  }

  function hashHelper(address _receiver, bytes32 _secret, uint _move, uint _gameID) public view returns(bytes32 puzzle){
    require(_move != 0);
    require(_move <= 3);
    return keccak256(abi.encodePacked(this,_receiver,_secret,_gameID,_move));
  }
  
  function hashToMoveConverter(bytes32 _secret, uint _gameID, bytes32 _origHash) public view returns(Moves move){
      if(keccak256(abi.encodePacked(this,msg.sender,_secret,_gameID,uint(0))) == _origHash) return Moves(0);
      else if(keccak256(abi.encodePacked(this,msg.sender,_secret,_gameID,uint(1))) == _origHash) return Moves(1);
      else if(keccak256(abi.encodePacked(this,msg.sender,_secret,_gameID,uint(2))) == _origHash) return Moves(2);
      else if(keccak256(abi.encodePacked(this,msg.sender,_secret,_gameID,uint(3))) == _origHash) return Moves(3);
      else return Moves(0);
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
  function withdraw(uint _amount) whenNotPaused public returns(bool success){
    require(fundsStore[msg.sender].amount >= _amount,"[WD001] No enough funds in the account");
    fundsStore[msg.sender].amount = fundsStore[msg.sender].amount.sub(_amount);
    emit LogWithdraw(msg.sender,_amount,fundsStore[msg.sender].amount);
    msg.sender.transfer(_amount);
    return true;
  }
  /** END */
}