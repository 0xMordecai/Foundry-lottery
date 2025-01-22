// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import {Script} from "../forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

/**

 * @notice We will then create an abstract contract `CodeConstants` where we define some network IDs. 
 The `HelperConfig` contract will be able to use them later through inheritance.

*/
abstract contract CodeConstants {
    /* VRF Mock Values */
    uint96 public constant MOCK_BASE_FEE = 0.25 ether;
    uint96 public constant MOCK_GAS_PRICE = 1e9;
    int256 public constant MOCK_WEI_PER_UNIT_LINK = 4e15;

    uint256 public constant ETH_SEPLOIA_CHAIN_ID = 11155111;
    uint256 public constant LOCAL_CHAIN_ID = 31337;

    address public constant LINK_TOKEN_ADDRESS =
        0x779877A7B0D9E8603169DdbD7836e478b4624789;
}

contract HelperConfig is CodeConstants, Script {
    /**
     * @notice ERRORS
     */
    error HelperConfig__InvalidChainId();

    /**
     * @notice define a **Network Configuration Structure**
     */
    struct NetworkConfig {
        uint256 entrenceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint32 callbackGasLimit;
        uint256 subscriptionId;
        address link;
        address account;
    }

    NetworkConfig public localNetworkConfig;
    mapping(uint256 chainId => NetworkConfig) public networkConfigs;

    // VRFCoordinatorV2_5Mock vRFCoordinatorV2_5Mock =
    //     new VRFCoordinatorV2_5Mock();

    constructor() {
        networkConfigs[ETH_SEPLOIA_CHAIN_ID] = getSepoliaEthConfig();
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid); // Get the config for the current chain
    }

    function setConfig(
        uint256 chainId,
        NetworkConfig memory networkConfig
    ) public {
        networkConfigs[chainId] = networkConfig;
    }

    /**
     * @notice We'll then define two functions that return the _network-specific configuration_.
     *  We'll set up these functions for Sepolia and a local network.
     */

    /**
     * @notice We also have to build a function to fetch the appropriate configuration based on the actual chain ID.
     *  This can be done first by verifying that a VRF coordinator exists.
     *  In case it does not and we are not on a local chain, we'll revert.
     */
    function getConfigByChainId(
        uint256 chainId
    ) public returns (NetworkConfig memory) {
        if (networkConfigs[chainId].vrfCoordinator != address(0)) {
            return networkConfigs[chainId];
        } else if (chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvailEthConfig();
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }

    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        return
            NetworkConfig({
                entrenceFee: 0.01 ether,
                interval: 30, // 30 seconds
                vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
                gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
                callbackGasLimit: 100000, // 100,000 gas
                subscriptionId: 0,
                link: LINK_TOKEN_ADDRESS,
                account: 0x921758531C555a5cD9B0c0f809538e650ab46F09
            });
    }

    function getOrCreateAnvailEthConfig()
        public
        returns (NetworkConfig memory)
    {
        // Check to see if we set an active network config
        if (localNetworkConfig.vrfCoordinator != address(0)) {
            return localNetworkConfig;
        }
        // Deploy Mocks
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock vrfCoordinatorMock = new VRFCoordinatorV2_5Mock(
            MOCK_BASE_FEE,
            MOCK_GAS_PRICE,            MOCK_WEI_PER_UNIT_LINK
        );
        LinkToken linkToken = new LinkToken();
        vm.stopBroadcast();
        // Set the mock VRF coordinator
        localNetworkConfig = NetworkConfig({
            entrenceFee: 0.01 ether,
            interval: 30, // 30 seconds
            vrfCoordinator: address(vrfCoordinatorMock),
            // gasLan Doesn't matter here
            gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
            callbackGasLimit: 100000, // 100,000 gas
            subscriptionId: 0,
            link: address(linkToken),
            account: 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38 // from Base.sol
        });
        return localNetworkConfig;
    }
}
