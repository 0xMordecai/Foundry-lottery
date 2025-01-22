// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {VRFConsumerBaseV2Plus} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title A simple Raffle contract
 * @author Mohamed Lahrach
 * @notice This contract is for creating a simple raffle
 * @dev Implements ChainLink VRFv2.5
 */
contract Raffle is VRFConsumerBaseV2Plus {
    /** ERRORS */
    error Raffle__SendMoreToEnterRaffle();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpkeepNotNeeded(
        uint256 balance,
        uint256 length,
        uint256 raffleState
    );

    /**  Type Declarations */
    enum RaffleState {
        OPEN, //  0
        CALCULATING //  1
    }

    /** State Variables */
    uint256 private immutable i_entrenceFee;
    /**
     * @dev The duration of the lottery in seconds
     */
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    uint256 private immutable i_interval;
    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    address private s_recentWinner;

    RaffleState private s_raffleState;

    /**Events */
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    constructor(
        uint256 entrenceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entrenceFee = entrenceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
        i_keyHash = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() external payable {
        // require(msg.value >= i_entrenceFee,"Not enough ETH sent!");
        if (msg.value < i_entrenceFee) {
            revert Raffle__SendMoreToEnterRaffle();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }

        s_players.push(payable(msg.sender));
        // Emit an event when we update a dynamic array or mapping
        // Named events with the function name reversed
        emit RaffleEntered(msg.sender);
    }

    // When should the winner be picked?
    /**
     * @dev this the function that chainlink nodes will call to see
     * if the lottery is ready to have a winner picked.
     * The following should be true in order for upkeepNeeded to be true:
     * 1. The time interval has passed since the last winner was picked.
     * 2. The lottery is in an open state.
     * 3. The contract has a balance greater than 0 (there are players)
     * 4. Implicity, the subscription has Link
     * @param -ignored
     * @return upkeepNeeded -true if the function should run, false if not
     * @return -ignored
     */
    function checkUpkeep(
        bytes memory /* checkData */
    ) public view returns (bool upkeepNeeded, bytes memory /* performData */) {
        // 1. Check if the time interval has passed since the last winner was picked.
        bool timeHasPassed = ((block.timestamp - s_lastTimeStamp) >=
            i_interval);

        // 2. Check if the lottery is in an open state.
        bool isRaffleOpen = (s_raffleState == RaffleState.OPEN);
        // 3. Check if the contract has a balance greater than 0
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded =
            timeHasPassed &&
            isRaffleOpen &&
            hasBalance &&
            hasPlayers;
        return (upkeepNeeded, "");
    }

    function performUpkeep(bytes calldata /* performData */) external {
        // check tto see if enough time has passed
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            ); // if not, do nothing
        }
        // set s_raffleState to CALCULATING
        s_raffleState = RaffleState.CALCULATING;
        // Get our random number from ChainLink VRF
        // 1. Request RNG(Random Number Genrator)
        // 2. Get RNG
        /** 1. Send Request with this function */
        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient
            .RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            });

        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);
        emit RequestedRaffleWinner(requestId);
    }

    /** 2. Gonna proccess the response with this function */
    // CEI: the Checks-Effects-Interactions pattern for secure and efficient smart contract development.
    function fulfillRandomWords(
        uint256 /**requestId*/,
        uint256[] calldata randomWords
    ) internal virtual override {
        // Checks(Requiers, Conditions)

        // s_players = 10;
        // rng = 12
        // 12 % 10 = 2 <-
        // 2151545154484894818189 % 10 = 9

        // Effect (Internal Contract State)
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;

        //  set s_raffleState to OPEN and restart the Lottery by resetting s_players array an s_lastTimeStamp
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        emit WinnerPicked(recentWinner);

        // Interactions (External Contract Interactions)
        // Send The Prize To winner
        (bool success, ) = recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
    }

    //** Getters function */

    function getEntrenceFee() external view returns (uint256) {
        return i_entrenceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayer(uint256 indexOfPlayer) external view returns (address) {
        return s_players[indexOfPlayer];
    }

    function getLastTimeStamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getRecentWinner() external view returns (address) {
        return s_recentWinner;
    }
}
