// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

/**
 * @title  A simple raffle contract
 *     @author Ajayi Samuel
 *     @notice This contract is for creating a simple raffle
 *     @dev Implements Chainlink VRFv2
 */
contract Raffle is VRFConsumerBaseV2 {
    error Raffle_notEnoughEthSent();
    error Raffle__TransferFailed();
    error Raffle__NotOpen();
    error Raffle__UpkeepNotNeeded(uint256 currentBalance, uint256 numPlayers, RaffleState raffleState);

    enum RaffleState {
        OPEN,
        CALCULATING
    }

    uint16 private constant REQ_CONFIRMATION = 3;
    uint256 private immutable entranceFee;
    VRFCoordinatorV2Interface private immutable VRFCoordinator;
    bytes32 private immutable gaslane;
    uint32 private immutable callbackGasLimit;
    address payable[] private players;
    uint64 immutable subId;
    uint256 private immutable interval; //this is the duration of the lottery in seconds
    uint256 private lastTimeStamp;
    uint32 private constant WORDS = 1;
    address private recentWinner;
    RaffleState private raffleState;

    event enteredRaffle(address indexed player);
    event WinnerPicked(address indexed winner);

    constructor(
        uint256 fee,
        uint256 _interval,
        address _VRFCoordinator,
        bytes32 _gaslane,
        uint64 _subId,
        uint32 _callBackGasLimit
    ) VRFConsumerBaseV2(_VRFCoordinator) {
        entranceFee = fee;
        interval = _interval;
        lastTimeStamp = block.timestamp;
        VRFCoordinator = VRFCoordinatorV2Interface(_VRFCoordinator);
        gaslane = _gaslane;
        subId = _subId;
        raffleState = RaffleState.OPEN;
        callbackGasLimit = _callBackGasLimit;
    }

    function enterRaffle() external payable {
        if (msg.value < entranceFee) {
            revert Raffle_notEnoughEthSent();
        }
        if (raffleState != RaffleState.OPEN) {
            revert Raffle__NotOpen();
        }
        players.push(payable(msg.sender));
        emit enteredRaffle(msg.sender);
    }

    //
    function checkUpKeep(bytes memory)
        /*param*/
        public
        view
        returns (bool upKeepNeeded, bytes memory /*another param*/ )
    {
        bool timeHasPassed = (block.timestamp - lastTimeStamp) >= interval;
        bool isOpen = RaffleState.OPEN == raffleState;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = players.length > 0;
        upKeepNeeded = (timeHasPassed && isOpen && hasBalance && hasPlayers);
        return (upKeepNeeded, "0x0");
    }

    //get a random number and use it to pick a player and it has to be automatically called
    function performUpkeep(bytes calldata /*performData */ ) external {
        (bool upkeepNeeded,) = checkUpKeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(address(this).balance, players.length, RaffleState(raffleState));
        }
        if ((block.timestamp - lastTimeStamp) < interval) {
            revert Raffle__TransferFailed();
        }

        raffleState = RaffleState.CALCULATING;

        VRFCoordinator.requestRandomWords(gaslane, subId, REQ_CONFIRMATION, callbackGasLimit, WORDS);
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randWords) internal override {
        uint256 indexOfWinner = randWords[0] % players.length;
        address payable winner = players[indexOfWinner];
        recentWinner = winner;
        raffleState = RaffleState.OPEN;
        players = new address payable[](0);
        lastTimeStamp = block.timestamp;
        emit WinnerPicked(winner);
        (bool success,) = recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert();
        }
    }

    function getFee() external view returns (uint256) {
        return entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return raffleState;
    }

    function getPlayer(uint256 index) external view returns (address) {
        return players[index];
    }
}
