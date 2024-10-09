// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {Link} from "../test/mocks/Link.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        uint256 fee;
        uint256 _interval;
        address _VRFCoordinator;
        bytes32 _gaslane;
        uint64 _subId;
        uint32 _callBackGasLimit;
        address link;
    }

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            fee: 0.01 ether,
            _interval: 30,
            _VRFCoordinator: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625,
            _gaslane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
            _subId: 0,
            _callBackGasLimit: 500000,
            link: 0x779877A7B0D9E8603169DdbD7836e478b4624789
        });
    }

    NetworkConfig public activeNetworkConfig;

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if (activeNetworkConfig._VRFCoordinator != address(0)) {
            return activeNetworkConfig;
        }

        vm.startBroadcast();
        VRFCoordinatorV2Mock vrfCoordinatorMock = new VRFCoordinatorV2Mock(0.25 ether, 1e9);
        Link link = new Link();
        vm.stopBroadcast();

        return NetworkConfig({
            fee: 0.01 ether,
            _interval: 30,
            _VRFCoordinator: address(vrfCoordinatorMock),
            _gaslane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
            _subId: 0, //script will add this
            _callBackGasLimit: 500000,
            link: address(link)
        });
    }
}
