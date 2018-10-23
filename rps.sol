pragma solidity ^0.4.7;
import "remix_tests.sol"; // this import is automatically injected by Remix.


contract StateMachine {
  enum Stages {
               AcceptingBet,
               WaitingForCommitments,
               WaitingForReveals,
               Finished
  }

  // Start State of FSM.
  Stages public stage = Stages.AcceptingBet;

  // Contract Variables
  // Players, Hashes of their Play, bid
  address public playerOne;
  address public playerTwo;
  bytes32 public playerOneBlindedPlay;
  bytes32 public playerTwoBlindedPlay;
  uint public bet;
  bool public playerOnePlayConfirmed;
  bool public playerTwoPlayConfirmed;

  uint public creationTime = now;

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

  // Perform timed transitions. Be sure to mention
  // this modifier first, otherwise the guards
  // will not take the new stage into account.
  // TODO: Change this 
  modifier timedTransitions() {
    if (stage == Stages.AcceptingBlindedBids &&
        now >= creationTime + 10 days)
      nextStage();
    if (stage == Stages.RevealBids &&
        now >= creationTime + 12 days)
      nextStage();
    // The other stages transition by transaction
    _;
  }

  //////////////////////////////////////////
  //// INTERACTIVE FUNCTIONS START HERE ////
  //////////////////////////////////////////

    /// Place your bet by paying it with the transaction.
  function placeBet()
    public
    payable
    timedTransitions
    atStage(Stages.AcceptingBet)
  {
    // Check if we need to decline the transaction
    require((msg.sender != playerOne), "Player 1, you have already placed a bet!");
    if (playerOne != 0) {
      // The person placing the bet is the first person!
      playerOne = message.sender;
      // Accept any bet value
      bet = message.value;
        } else {
      // The person that is placing the bet is the second player!
      require((msg.value == bet), "Bet must be " + bet);
      transitionNext(); // Both bets have been placed, we can continue to the next phase.
    }
  }


  /// Commit to a play here.
  /// Invoke with _blindedPlay = sha256(play, secret)
  /// WHERE
  ///   play = "rock", "paper", "scissors"
  ///   secret = a random string
  /// For example, to commit to scissors, I create a random
  /// string (eg. "fkwQoISp2u") and invoke commit as follows:
  /// commit(sha256("scissors","fkwQoISp2u"))
  ///
  /// NOTE:
  /// You can only win if your play is correctly verified
  /// during the revealing phase.
  function commit(bytes32 _blindedPlay)
    public
    timedTransitions
    atStage(Stages.waitingForCommitments)
  {
    // Check who is the sender
    if (msg.sender == playerOne) {
      require(playerOneBlindedPlay == 0, "You can not change your bid!");
      playerOneBlindedPlay =_blindedPlay;
    } elseif {msg. sender == playerTwo} {
      require(playerTwoBlindedPlay == 0, "You can not change your bid!");
      playerTwoBlindedPlay =_blindedPlay;
    } else {
      require(false, "A game is in process and you are not currently playing! Try again later");
    }
    // Now see if both people bet something
    if (playerOneBlindedPlay != 0 && playerTwoBlindedPlay != 0) {
      transitionNext(); // Both players commited, next state.
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
                  bytes32[] _play,
                  bytes32[] _secret
                  )
    public
    timedTransitions
    atStage(stages.WaitingForReveals)
  {
    // Check who is the sender
    if (msg.sender == playerOne) {
      require(playerOneBlindedPlay == sha256(_play,_secret), "Reveal verification failed");
      playerOnePlay = _play;
    } elseif {msg.sender == playerTwo} {
      require(playerTwoBlindedPlay == sha256(_play,_secret), "Reveal verification failed");
      playerTwoPlay =_play;
    } else {
      require(false, "A game is in process and you are not currently playing! Try again later");
    }
    // Now see if both people revealed
    if (playerOnePlay != "" && playerTwoPlay != "") {
      transitionNext(); // Both players commited, next state.
    }
  }

  // This modifier goes to the next stage
  // after the function is done.
  modifier transitionNext()
  {
    _;
    nextStage();
  }

}
