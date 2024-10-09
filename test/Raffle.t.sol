// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {DeployRaffle} from "../script/Raffle.s.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";

contract RaffleTest is Test {
    event enteredRaffle(address indexed player);
    event WinnerPicked(address indexed winner);

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

    function testCantEnterWhenRaffleIsCalculating() public {
        vm.prank(player);
        raffle.enterRaffle{value: fee}();
        vm.warp(block.timestamp + _interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        vm.expectRevert(Raffle.Raffle__NotOpen.selector);
        vm.prank(player);
        raffle.enterRaffle{value: fee}();
    }
}
