// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import "../src/interfaces/IUniswapV2.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Deploy script to create a Uniswap V2 pair (WETH/RUB) and add initial liquidity.
///
/// PREREQUISITES:
/// 1. Deploy the Uniswap V2 Factory on Arbitrum Sepolia (or use the canonical one).
/// 2. Deploy the RubbiToken (RUB) on Arbitrum Sepolia.
/// 3. Have WETH and RUB tokens in the deployer wallet for liquidity.
/// 4. Set environment variables:
///    - PRIVATE_KEY: deployer private key
///    - UNISWAP_V2_FACTORY: factory contract address
///    - UNISWAP_V2_ROUTER: router contract address
///    - RUBBI_TOKEN_ADDRESS: deployed RUB token address
///    - WETH_ADDRESS: WETH address on Arbitrum Sepolia
contract SetupPairScript is Script {
    function run() public {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address factoryAddress = vm.envAddress("UNISWAP_V2_FACTORY");
        address routerAddress = vm.envAddress("UNISWAP_V2_ROUTER");
        address rubToken = vm.envAddress("RUBBI_TOKEN_ADDRESS");
        address wethAddress = vm.envAddress("WETH_ADDRESS");

        IUniswapV2Factory factory = IUniswapV2Factory(factoryAddress);
        IUniswapV2Router02 router = IUniswapV2Router02(routerAddress);

        vm.startBroadcast(privateKey);

        // Step 1: Create the WETH/RUB pair if it doesn't exist
        address existingPair = factory.getPair(wethAddress, rubToken);
        if (existingPair == address(0)) {
            console.log("Creating WETH/RUB pair...");
            address newPair = factory.createPair(wethAddress, rubToken);
            console.log("Pair created at:", newPair);
        } else {
            console.log("Pair already exists at:", existingPair);
        }

        // Step 2: Approve router to spend RUB tokens
        IERC20 rubTokenERC20 = IERC20(rubToken);
        rubTokenERC20.approve(routerAddress, type(uint256).max);
        console.log("Router approved to spend RUB tokens");

        // Step 3: Add liquidity (ETH + RUB)
        // Adjust these amounts based on your desired initial price
        // Example: 1 ETH = 3200 RUB (at $1 = 50 RUB, ETH = $3200)
        uint256 rubAmount = 3200 ether;  // 3200 RUB tokens
        uint256 ethAmount = 1 ether;      // 1 ETH
        uint256 rubMin = (rubAmount * 95) / 100; // 5% slippage
        uint256 ethMin = (ethAmount * 95) / 100;

        console.log("Adding liquidity...");
        console.log("ETH amount:", ethAmount);
        console.log("RUB amount:", rubAmount);

        (uint256 amountToken, uint256 amountETH, uint256 liquidity) = router.addLiquidityETH{value: ethAmount}(
            rubToken,
            rubAmount,
            rubMin,
            ethMin,
            address(this),
            block.timestamp + 600
        );

        console.log("Liquidity added!");
        console.log("RUB deposited:", amountToken);
        console.log("ETH deposited:", amountETH);
        console.log("LP tokens received:", liquidity);

        vm.stopBroadcast();

        // Log the pair address for reference
        address pair = factory.getPair(wethAddress, rubToken);
        console.log("\n=== SUMMARY ===");
        console.log("Factory:", factoryAddress);
        console.log("Router:", routerAddress);
        console.log("WETH:", wethAddress);
        console.log("RUB:", rubToken);
        console.log("Pair:", pair);
        console.log("LP tokens minted:", liquidity);
    }
}
