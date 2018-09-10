pragma solidity ^0.4.24;


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
    bool forFitted;
  }
  mapping(uint => GameParams) public games;  
  
  struct Funds{
    // NOTE: Here betAmount + amount = Total Amount Deposited
    uint amount; // Amount deposited by the player which can is withdrawable
    uint betAmount; // Amount which is locked / beted on the 
    address contrAddress; // Address of the contract having amount parked
  }
  mapping(address => Funds) public fundsStore;
  /** End */
  

  event LogPlayer1CreateNewGame(address indexed playerAddress, uint betAmount, uint gameID );
  event LogPlayer2JoinGame(address indexed playerAddress, uint gameID, uint betAmount );
  event LogSubmitMove(address indexed playerAddress, uint _gameID, bytes32 _moveHash );
  event LogCheckWinner(address indexed calleAddress, uint _gameID, address winner, uint wonAmount, uint amountReturned);  
  event LogRevealMove(address indexed playerAddress, uint indexed _gameID, bytes32 _secret, uint _moveID);  
  event LogForFitGame(address indexed playerAddress, uint _gameID, uint amountReturned);
  event LogDepositFunds(address indexed playerAddress, uint amount );
  event LogWithdraw(address indexed playerAddress, uint amount, uint balance);
  

  modifier gameNotForfeited(uint _gameID){
    require(games[_gameID].forFitted == false, "[GNF] Game forfitted");
    _;
  }

  /**
   * @dev Function for creating new game and beting amount
   * Function Code: [CG]
   * @param _gameID Game ID to be created on-chain
   */
  function player1CreateNewGameAndBet(uint _gameID/*, uint _betAmount*/) whenNotPaused  payable public returns(bool success){
    require(msg.value > 0, "[DF001] Invalid Message Value"); 
    require(games[_gameID].p1Bet == 0, "[DF002] Game with same ID already used");
    require(games[_gameID].player1 == address(0), "[DF002] Game with same ID already used");
    games[_gameID].player1 = msg.sender;
    games[_gameID].p1Bet = games[_gameID].p1Bet.add(msg.value);
    emit LogPlayer1CreateNewGame(msg.sender,msg.value, _gameID);
    return true;
  }

  /**
   * @dev Function for joining game. Player should call this function
   * with exact bet amount of player 1 to join the game. 
   * Function Code: [JG]
   * This function will be used in two ways:   
   * @param _gameID ID of the game to join
   */
  function player2JoinGameAndBet(uint _gameID /*, uint _betAmount */) whenNotPaused gameNotForfeited(_gameID) payable public returns(bool success){
    // require(_betAmount >0, "[JG001] Invalid values" );  /* Not Required! Will be removed in next iteraton */
    // require(fundsStore[msg.sender].amount >= _betAmount, "[JG002] Should deposit funds before playing");
    require(games[_gameID].player1 != address(0), "[JG003] Game does not exist");
    require(games[_gameID].player2 == address(0), "[JG004] Player already part of the game"); 
    require(games[_gameID].p1Bet == msg.value, "[JG003] Bet amount should match with player1's");// Check if player 2 bet matches player 1
    
    if(games[_gameID].player1 != msg.sender){
        games[_gameID].player2 = msg.sender;
        games[_gameID].p2Bet = games[_gameID].p2Bet.add(msg.value); // Suppoused to be 0  
    }else{
        games[_gameID].p1Bet = games[_gameID].p1Bet.add(msg.value); 
    } 
    emit LogPlayer2JoinGame(msg.sender,_gameID,msg.value);    
    return true;
  }

  /**
   * @dev Procedure for submitting move to an existing Game. 
   * Function Code: [SM]
   * @param _gameID Game ID for which move is geting submitted. Player should either create a game OR 
   * JOIN a game before calling this procedure.
   */
  function submitMove(uint _gameID,bytes32 _moveHash) whenNotPaused gameNotForfeited(_gameID) public returns(bool success){
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
  function checkWinner(uint _gameID) gameNotForfeited(_gameID) public returns(bool success){
    require(games[_gameID].player1 != address(0), "Invalid Game ID");
    if(msg.sender != address(this)){
        require(games[_gameID].player1 == msg.sender || 
                games[_gameID].player2 == msg.sender , "[CW001] Player is not part of the game");
    }else{
        require(games[_gameID].player1 != address(0) && 
                    games[_gameID].player2 != address(0) , "[CW002] All players have not joined the game");
    }
    /* Move Hash should be provided */
    require(games[_gameID].p1MoveHash != bytes32(0) &&
                games[_gameID].p2MoveHash != bytes32(0) &&
                games[_gameID].p1MoveID != Moves(0) &&
                games[_gameID].p2MoveID != Moves(0), "[CW003] All moves not submitted");
    
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
        games[_gameID].p2MoveHash = bytes32(0);
        fundsStore[games[_gameID].player1].amount = fundsStore[games[_gameID].player1].amount.add(games[_gameID].p2Bet.add(games[_gameID].p1Bet));
        wonAmount = games[_gameID].p2Bet;
        amountReturned = games[_gameID].p1Bet.add(games[_gameID].p2Bet);
        games[_gameID].p1Bet = 0;
        games[_gameID].p2Bet = 0;
        games[_gameID].lastWinner = games[_gameID].player1;
        emit LogCheckWinner(msg.sender, _gameID, games[_gameID].player1, wonAmount, amountReturned);
    }else{
        // P2 won
        games[_gameID].p1MoveID = Moves(0);
        games[_gameID].p2MoveID = Moves(0);
        games[_gameID].p1MoveHash = bytes32(0);
        games[_gameID].p2MoveHash = bytes32(0);
        // Amount bet by P1 will go to P2 and amount bet by P2 will be returned to the P2 account
        fundsStore[games[_gameID].player2].amount = games[_gameID].p1Bet.add(games[_gameID].p2Bet);
        // fundsStore[games[_gameID].player2].amount = fundsStore[games[_gameID].player2].amount.add(games[_gameID].p2Bet);
        wonAmount = games[_gameID].p1Bet;
        amountReturned = games[_gameID].p1Bet.add(games[_gameID].p2Bet);
        games[_gameID].p1Bet = 0;
        games[_gameID].p2Bet = 0;
        games[_gameID].lastWinner = games[_gameID].player2;
        emit LogCheckWinner(msg.sender, _gameID, games[_gameID].player1, wonAmount, amountReturned);
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
   * @param _moveID Move ID player executed   
   **/
  function revealMove(bytes32 _secret, uint _gameID, uint _moveID) public returns(bool success){      
      require(games[_gameID].p1MoveHash != bytes32(0), "[RM002]: Please submit your move first");
      require(games[_gameID].p2MoveHash != bytes32(0), "[RM002]: Please submit your move first");
      
      /* Not allowed to call this function again if move is already revealed */
      if(games[_gameID].player1 == msg.sender){ // Player 1 is calling this function
          require(games[_gameID].p1MoveID == Moves(0), "[RM003] Not allowed to reveal again");
          require(hashHelper(msg.sender,_secret,_moveID,_gameID) == games[_gameID].p1MoveHash, "[RM004] Invalid secret or move");
          games[_gameID].p1MoveID = Moves(_moveID);          
      }else if(games[_gameID].player2 == msg.sender){ // Player2 is calling this function
        require(games[_gameID].p2MoveID == Moves(0), "[RM003] Not allowed to reveal again");    
        require(hashHelper(msg.sender,_secret,_moveID,_gameID) == games[_gameID].p2MoveHash, "[RM004] Invalid secret or move");
        games[_gameID].p2MoveID = Moves(_moveID);          
      }else{
        revert("Not a player");
      }
      // Check if winner can be announced
      // Check if winner can be announced
      if(games[_gameID].p1MoveHash != bytes32(0) && 
         games[_gameID].p2MoveHash != bytes32(0) &&
          games[_gameID].p1MoveID != Moves(0) &&
           games[_gameID].p2MoveID != Moves(0)){
         // Check the winner
          this.checkWinner(_gameID);
      }
      emit LogRevealMove(msg.sender,  _gameID, _secret, _moveID);          
      return true;
  }

  function hashHelper(address _receiver, bytes32 _secret, uint _move, uint _gameID) public view returns(bytes32 puzzle){
    require(_move != 0);
    require(_move <= 3);
    return keccak256(abi.encodePacked(this,_receiver,_secret,_gameID,_move));
  }
  
  /**
   * @dev Function for forfiting the game. This will be allowed ONLY when: 
   * * Player 2 have not joined the game -OR-
   * * Both players have finished last move (respective moveID's and hashes are null)
   * function code: [P1FT]
   * @param _gameID to forfit the tame
   */
  function player1ForfeitGame(uint _gameID) public returns(bool success){
    require(games[_gameID].player1 == msg.sender, "[P1FT] Player 1 can only forfit the game" );
    require(games[_gameID].p2MoveID == Moves(0), "[P1FT] Too late. Player2 have played his move.");
    require(games[_gameID].p2MoveHash == bytes32(0), "[P1FT] Too late. Player 2 already played his/her move");
    // Do the accounting entries
    uint p1Bet = games[_gameID].p1Bet;
    fundsStore[games[_gameID].player1].amount = fundsStore[games[_gameID].player1].amount.add(games[_gameID].p1Bet);
    games[_gameID].p1Bet = 0;
    games[_gameID].forFitted = true;
    // Emit event
    emit LogForFitGame(msg.sender, _gameID, p1Bet);
    return true;
  }

  /**
   * @dev Function for forfiting the game. This will be allowed ONLY when: 
   * * Player 1 have not submitted his / her move   
   * function code: [P2FT]
   * @param _gameID to forfit the tame
   */
  function player2ForfeitGame(uint _gameID) public returns(bool success){
    require(games[_gameID].player2 == msg.sender, "[P2FT] Player 2 can only forfit the game" );
    require(games[_gameID].p1MoveID == Moves(0), "[P2FT] Too late. Player2 have played his move.");
    require(games[_gameID].p1MoveHash == bytes32(0), "[P2FT] Too late. Player 2 already played his/her move");
    // Do the accounting entries
    uint p2Bet = games[_gameID].p2Bet;
    fundsStore[games[_gameID].player2].amount = fundsStore[games[_gameID].player2].amount.add(games[_gameID].p2Bet);
    games[_gameID].p2Bet = 0;
    games[_gameID].forFitted = true;
    // Emit event
    emit LogForFitGame(msg.sender, _gameID, p2Bet);
    return true;
  }
  
 
  /**
   * @dev Function for depositing funds to the contract
   * Function code: [DF]
   */
  function depositPlayerFunds(uint _gameID) whenNotPaused gameNotForfeited(_gameID) public payable returns(bool success){
    require(msg.value > 0, "[DF001] Invalid Message Value"); 
    require(games[_gameID].player1 != address(0) &&
                games[_gameID].player2 != address(0), "Game does not exist");
    if(msg.sender == games[_gameID].player1){
        games[_gameID].p1Bet = games[_gameID].p1Bet.add(msg.value);
    }else if(msg.sender == games[_gameID].player2){
        games[_gameID].p2Bet = games[_gameID].p2Bet.add(msg.value);
    }
    emit LogDepositFunds(msg.sender,msg.value);
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
}