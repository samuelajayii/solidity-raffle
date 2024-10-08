// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription} from "./Interactions.s.sol";

contract DeployRaffle is Script {
    function run() external returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        (
            uint256 fee,
            uint256 _interval,
            address _VRFCoordinator,
            bytes32 _gaslane,
            uint64 _subId,
            uint32 _callBackGasLimit
        ) = helperConfig.activeNetworkConfig();

        if (_subId == 0) {
            CreateSubscription createSubscription = new CreateSubscription();
            _subId = createSubscription.createSubscription(_VRFCoordinator);
        }

        vm.startBroadcast();
        Raffle raffle = new Raffle(fee, _interval, _VRFCoordinator, _gaslane, _subId, _callBackGasLimit);
        vm.stopBroadcast();
        return (raffle, helperConfig);
    }
}
