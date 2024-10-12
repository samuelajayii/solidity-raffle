// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {DeployRaffle} from "../script/Raffle.s.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {Vm} from 'forge-std/Vm.sol';
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract RaffleTest is Test {
    event enteredRaffle(address indexed player);
    event WinnerPicked(address indexed winner);
    event RequestedRaffle(uint256 indexed requestId);

    Raffle raffle;
    HelperConfig helperConfig;
    address public player = makeAddr("player");
    uint256 public constant STARTING_BALANCE = 100 ether;
    uint256 fee;
    uint256 _interval;
    address _VRFCoordinator;
    bytes32 _gaslane;
    uint64 _subId;
    uint32 _callBackGasLimit;
    address link;

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();
        (fee, _interval, _VRFCoordinator, _gaslane, _subId, _callBackGasLimit, link) =
            helperConfig.activeNetworkConfig();
        vm.deal(player, STARTING_BALANCE);
    }

    function testGetRaffleState() public {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testRaffleRevertWhenNotEnoughEthPaid() public {
        vm.prank(player);
        vm.expectRevert(Raffle.Raffle_notEnoughEthSent.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayerWhenEntered() public {
        vm.prank(player);
        raffle.enterRaffle{value: fee}();
        address playerRecord = raffle.getPlayer(0);
        assert(playerRecord == player);
    }

    function testEmitsEvent() public {
        vm.prank(player);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit enteredRaffle(player);
        raffle.enterRaffle{value: fee}();
    }

    function testCantEnterWhenRaffleIsCalculating() public RaffleEnterAndTimePassed {
        raffle.performUpkeep("");

        vm.expectRevert(Raffle.Raffle__NotOpen.selector);
        vm.prank(player);
        raffle.enterRaffle{value: fee}();
    }

    function testCheckUpkeepReturnsFalseIfItHasNoBalance() public {
        vm.warp(block.timestamp + _interval + 1);
        vm.roll(block.number + 1);
        (bool upkeepNeeded,) = raffle.checkUpKeep("");
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfRaffleIsntOpen() public RaffleEnterAndTimePassed {
        raffle.performUpkeep("");
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        (bool upkeepNeeded,) = raffle.checkUpKeep("");
        assert(raffleState == Raffle.RaffleState.CALCULATING);
        assert(upkeepNeeded == false);
    }

    function testCheckUpkeepReturnsFalseIfEnoughTimeHasntPassed() public {
        vm.prank(player);
        raffle.enterRaffle{value: fee}();
        (bool upkeepNeeded,) = raffle.checkUpKeep("");
        assert(!upkeepNeeded);
    }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        Raffle.RaffleState rState = raffle.getRaffleState();
        vm.expectRevert(
            abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector, currentBalance, numPlayers, rState)
        );
        raffle.performUpkeep("");
    }

    function testCheckUpkeepReturnsTrueWhenParametersGood() public RaffleEnterAndTimePassed {
        (bool upkeepNeeded,) = raffle.checkUpKeep("");
        assert(upkeepNeeded);
    }

    modifier RaffleEnterAndTimePassed() {
        vm.prank(player);
        raffle.enterRaffle{value: fee}();
        vm.warp(block.timestamp + _interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function testPerformUpkeepUpdatesRaffleStateAndEmitRequestId() public RaffleEnterAndTimePassed {
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        assert(uint256(requestId) > 0);
        Raffle.RaffleState rState = raffle.getRaffleState();
        assert(uint256(rState) == 1);
    }

     function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(uint256 randomRequestId) public RaffleEnterAndTimePassed {
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(_VRFCoordinator).fulfillRandomWords(randomRequestId, address(raffle));

    }

    function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney() public RaffleEnterAndTimePassed {
        uint256 additionalEntrances = 3;
        uint256 startingIndex = 1;

        for (uint256 i = startingIndex; i < startingIndex + additionalEntrances; i++) {
            address newPlayer = address(uint160(i));
            hoax(newPlayer, STARTING_BALANCE); // deal 1 eth to the player
            raffle.enterRaffle{value: fee}();
        }

        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

       VRFCoordinatorV2Mock(_VRFCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));



        uint256 endingTimeStamp = raffle.getLastTimeStamp();
        uint256 prize = fee * (additionalEntrances + 1);

        assert(uint256(raffle.getRaffleState()) == 0);
        assert(raffle.getRecentWinner() != address(0));
        assert(raffle.getLengthOfPlayers() == 0);
        assert(raffle.getRecentWinner().balance == STARTING_BALANCE + prize - fee);

    }
}
