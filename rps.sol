pragma solidity ^0.4.7;
import "remix_tests.sol"; // this import is automatically injected by Remix.


contract UltimateRPS {
  enum Stages {
               AcceptingBet,
               WaitingForCommitments,
               WaitingForReveals,
               DecidingWinner,
               Finished
  }

  // Start State of FSM.
  Stages public stage = Stages.AcceptingBet;

  // Contract Variables
  // Players, Hashes of their Play, bid
  address public playerOne;
  address public playerTwo;
  string public playerOneBlindedPlay;
  string public playerTwoBlindedPlay;
  string public playerOnePlay;
  string public playerTwoPlay;
  uint public bet;
  bool public playerOnePlayConfirmed;
  bool public playerTwoPlayConfirmed;
  string public temp1;
  bytes32 public temp2;

  
  uint public stageTime = now;

  constructor() public {
    playerOne = address(0);
    playerTwo = address(0);
    playerOneBlindedPlay = "";
    playerTwoBlindedPlay = "";
    playerOnePlay = "";
    playerTwoPlay = "";
    bet = 0;
  }


  //////////////////////////////
  ////// FSM Facilitation //////
  //////////////////////////////
  modifier atStage(Stages _stage) {
    require(
            stage == _stage,
            "Function cannot be called at this time."
            );
    _;
  }

  function nextStage() internal {
    stage = Stages(uint(stage) + 1);
  }

  function restart() internal {
    stage = Stages(0);
  }


  modifier transitionNext()
  {
    _;
    nextStage();
  }


  // Time limits for commit and reveal stage.
  modifier timedTransitions() {
    if (stage == Stages.WaitingForCommitments &&
        now >= stageTime + 3 hours)
      nextStage();
    if (stage == Stages.WaitingForReveals &&
        now >= stageTime + 3 hours)
      nextStage();
    _;
  }

  //////////////////////////////////////////
  //// INTERACTIVE FUNCTIONS START HERE ////
  //////////////////////////////////////////

  /// Place your bet by paying it with the transaction.
  function placeBet()
    public
    payable
    //  timedTransitions // Problem: what if no one places a bet? Need to add option for p1 to withdraw their bet if and only if no one else bets
    atStage(Stages.AcceptingBet)
  {
    // Check if we need to decline the transaction
    require((msg.sender != playerOne), "Player 1, you have already placed a bet!");
    if (playerOne == address(0)) {
      // The person placing the bet is the first person!
      playerOne = msg.sender;
      // Accept any bet value
      bet = msg.value;
      stageTime = now; // Set start time for the contract now to facilitate time-outs
    } else {
      // The person that is placing the bet is the second player!
      playerTwo = msg.sender;
      require((msg.value == bet), "Bet must be the same as first player's!");
      nextStage(); // Both bets have been placed, we can continue to the next phase.
    }
  }

  /// Cancel bet if no player 2 is willing to bet the same amount
  function withdraw()
    public
    atStage(Stages.AcceptingBet)
  {
    require(msg.sender == playerOne);
    require(bet > 0);
    uint amount = bet;
    resetVars();
    restart();
    require(msg.sender.send(amount));
   }

  /// Commit to a play here.
  /// Invoke with _blindedPlay = sha256(play, secret)
  /// WHERE
  ///   play = "rock", "paper", "scissors"
  ///   secret = a random string
  /// For example, to commit to scissors, I create a random
  /// string (eg. "fkwQoISp2u") and invoke commit as follows:
  /// commit(0xd828a29758a0448cf629b15829fa133042bc9981344f5fba470390726362803a)
  ///
  /// Get this hash in bash by doing echo -n "scissorsfkwQoISp2u" | sha256sum | awk '{print "0x"$1}'
  ///
  /// NOTE:
  /// You can only win if your play is correctly verified
  /// during the revealing phase.
  function commit(string _blindedPlay)
    public
    timedTransitions
    atStage(Stages.WaitingForCommitments)
  {
    // Check who is the sender
    if (msg.sender == playerOne) {
      require(compareStrings(playerOneBlindedPlay, ""), "You can not change your commitment!");
      playerOneBlindedPlay =_blindedPlay;
    } else if (msg. sender == playerTwo) {
      require(compareStrings(playerTwoBlindedPlay, ""), "You can not change your commitment!");
      playerTwoBlindedPlay =_blindedPlay;
    } else {
      require(false, "A game is in process and you are not currently playing! Try again later");
    }
    // Now see if both people bet something
    if (!compareStrings(playerOneBlindedPlay, "") && !compareStrings(playerTwoBlindedPlay, "")) {
      nextStage(); // Both players commited, next state.
    }
  }

  /// Reveal your blinded plays.
  /// WHERE
  ///  _play = "rock", "paper" or "scissors"
  ///  _secret = The random secret string used to commit. 
  /// NOTE:
  /// If you do NOT reveal your bid, the other player wins by default!
  /// TODO: What if no one reveals?
  function reveal(
                  string _play,
                  string _secret
                  )
    public
    timedTransitions
    atStage(Stages.WaitingForReveals)
  {
    // Check who is the sender
    if (msg.sender == playerOne) {
      require(compareStrings(playerOneBlindedPlay, toString(sha256(_play,_secret))), "Reveal verification failed: wrong hash!");
      require(checkPlayValid(_play), "Reveal verification failed: You must only play rock, paper or scissors");
      playerOnePlay = _play;
    } else if (msg.sender == playerTwo) {
      require(compareStrings(playerTwoBlindedPlay, toString(sha256(_play,_secret))), "Reveal verification failed: wrong hash!");
      require(checkPlayValid(_play), "Reveal verification failed: You must only play rock, paper or scissors");
      playerTwoPlay =_play;
    } else {
      require(false, "A game is in process and you are not currently playing! Try again later");
    }
    // Now see if both people revealed
    if (!compareStrings(playerOnePlay, "") && !compareStrings(playerTwoPlay,"")) {
      nextStage(); // Both players commited, next state.
    }
  }

  function decideOutcome()
    public
    atStage(Stages.DecidingWinner)
  {
    // First, assume that both parties revealed
    if (!compareStrings(playerOnePlay, "") && !compareStrings(playerTwoPlay,"")) {
      // Both revealed, we need to decide the winner based on the usual r-p-s rules
      if(compareStrings(playerOnePlay, playerTwoPlay)) {
        draw();
      } else if (compareStrings(playerOnePlay, "rock")) {
        if (compareStrings(playerTwoPlay, "paper")) {
          winTwo();
        } else if (compareStrings(playerTwoPlay, "scissors")) {
          winOne();
        }
      } else if (compareStrings(playerOnePlay, "paper")) {
        if (compareStrings(playerTwoPlay, "rock")) {
          winOne();
        } else if (compareStrings(playerTwoPlay, "scissors")) {
          winTwo();
        }
      } else if (compareStrings(playerOnePlay, "scissors")) {
        if (compareStrings(playerTwoPlay, "rock")) {
          winTwo();
        } else if (compareStrings(playerTwoPlay, "paper")) {
          winOne();
        }
      }
    } else if (!compareStrings(playerOnePlay, "") && compareStrings(playerTwoPlay, "")) {
      // Player One has revealed, player two has not -> 1 wins by default
      winOne();
    } else if (compareStrings(playerOnePlay, "") && !compareStrings(playerTwoPlay, "")) {
      // Player Two has revealed, player one has not -> 2 wins by default
      winOne();
    } else {
      // We should never reach this point unless both parties don't reveal.
      // We need to check if at least one party has committed. They will be refunded. Otherwise, we keep their bet.
      
      //require(false, "No one revealed!");
      resetVars();
    }
      restart();
    

  }

  ////////////////////////
  /// Helper Functions ///
  ////////////////////////
  
  // String compare function from
  // https://ethereum.stackexchange.com/questions/30912/how-to-compare-strings-in-solidity/30914#30914
  function compareStrings (string a, string b) view returns (bool){
    return keccak256(a) == keccak256(b);
   }
   
  // bytes32 to string (WHY DOES THIS HAVE TO BE DONE EXPLICITLY???)
  // TypeError: Explicit type conversion not allowed from "bytes32" to "string storage pointer"
  // https://ethereum.stackexchange.com/questions/2519/how-to-convert-a-bytes32-to-string
  // https://ethereum.stackexchange.com/questions/46321/store-literal-bytes4-as-string
  function toHexDigit(uint8 d) pure internal returns (byte) {                                                                                      
    if (0 <= d && d <= 9) {                                                                                                                      
        return byte(uint8(byte('0')) + d);                                                                                                       
    } else if (10 <= uint8(d) && uint8(d) <= 15) {                                                                                               
        return byte(uint8(byte('a')) + d - 10);                                                                                                  
    }                                                                                                                                            
    revert();                                                                                                                                    
  }                                                                                                                                                

  function toString(bytes32 code) public view returns (string) {                                                                                    
    bytes memory result = new bytes(66);                                                                                                         
    result[0] = byte('0');
    result[1] = byte('x');
    for (uint i=0; i<32; ++i) {
        result[2*i+2] = toHexDigit(uint8(code[i])/16);
        result[2*i+3] = toHexDigit(uint8(code[i])%16);
    }
    return string(result);
  }
  
  function checkPlayValid(string __play)
    private
    returns (bool isValid)
  {
    return(compareStrings(__play, "rock") || compareStrings(__play, "paper") || compareStrings(__play, "scissors"));
  }

  function winOne()
    private
  {
    // Reset all variables
    address payto = playerOne;
    uint tosend = bet * 2;
    resetVars();
    // And send bets to player One
    payto.transfer(tosend);
  }

  function winTwo()
    private
  {
    // Reset all variables
    address payto = playerTwo;
    uint tosend = bet * 2;
    resetVars();
    // And send bets to player One
    payto.transfer(tosend);
  }

  function draw()
    private
  {
    // Reset all variables
    address payto1 = playerOne;
    address payto2 = playerTwo;
    uint tosend = bet;
    resetVars();
    // And send bets to player One
    // use send() for best effort & protect against reentrancy
    payto1.send(tosend);
    payto2.send(tosend);
  }


  function resetVars()
    private
  {
    playerOne = address(0);
    playerTwo = address(0);
    playerOneBlindedPlay = "";
    playerTwoBlindedPlay = "";
    playerOnePlay = "";
    playerTwoPlay = "";
    bet = 0;
    playerOnePlayConfirmed = false;
    playerTwoPlayConfirmed = false;
  }



}
