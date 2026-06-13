// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import "../src/interfaces/IUniswapV2.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Creates the WETH/RUB pair on Uniswap V2 and adds initial liquidity.
///
/// Run AFTER DeploySwap.s.sol:
///   forge script script/SetupPair.s.sol --rpc-url <RPC> --broadcast --verify
///
/// Environment variables:
///   PRIVATE_KEY           — deployer private key (must hold WETH and RUB)
///   UNISWAP_V2_FACTORY    — factory address from DeploySwap
///   UNISWAP_V2_ROUTER     — router address from DeploySwap
///   RUBBI_TOKEN_ADDRESS   — RUB token address from DeploySwap
///   WETH_ADDRESS          — WETH address from DeploySwap
///   LIQUIDITY_RUB         — (optional) RUB amount for liquidity (default: 320000)
///   LIQUIDITY_ETH_WEI     — (optional) ETH amount for liquidity in wei (default: 100 ether)
///
/// IMPORTANT: Before running, ensure the deployer wallet has:
///   - Enough ETH to wrap into WETH + pay for gas
///   - Enough RUB tokens to provide liquidity
///
/// The script will:
///   1. Check if pair already exists; create it if not
///   2. Approve router to spend RUB
///   3. Wrap ETH into WETH
///   4. Approve router to spend WETH
///   5. Add liquidity via addLiquidityETH
///
contract SetupPairScript is Script {
    function run() public {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address factoryAddr = vm.envAddress("UNISWAP_V2_FACTORY");
        address routerAddr = vm.envAddress("UNISWAP_V2_ROUTER");
        address rubToken = vm.envAddress("RUBBI_TOKEN_ADDRESS");
        address wethAddr = vm.envAddress("WETH_ADDRESS");

        uint256 rubAmount = vm.envOr("LIQUIDITY_RUB", uint256(320_000 ether));
        uint256 ethAmount = vm.envOr("LIQUIDITY_ETH_WEI", uint256(100 ether));

        IUniswapV2Factory factory = IUniswapV2Factory(factoryAddr);
        IUniswapV2Router02 router = IUniswapV2Router02(routerAddr);

        vm.startBroadcast(privateKey);

        // Step 1: Create pair if it doesn't exist
        address existingPair = factory.getPair(wethAddr, rubToken);
        if (existingPair == address(0)) {
            console.log("Creating WETH/RUB pair...");
            address newPair = factory.createPair(wethAddr, rubToken);
            console.log("Pair created at:", newPair);
        } else {
            console.log("Pair already exists at:", existingPair);
        }

        // Step 2: Approve router to spend RUB tokens
        IERC20(rubToken).approve(routerAddr, rubAmount);
        console.log("Approved router to spend", rubAmount / 1e18, "RUB");

        // Step 3: Wrap ETH into WETH
        IERC20(wethAddr).approve(routerAddr, ethAmount);

        // Step 4: Add liquidity (RUB + ETH)
        console.log("Adding liquidity...");
        console.log("  RUB:", rubAmount / 1e18);
        console.log("  ETH:", ethAmount / 1e18);

        (uint256 amountToken, uint256 amountETH, uint256 liquidity) = router.addLiquidityETH{value: ethAmount}(
            rubToken,
            rubAmount,
            (rubAmount * 95) / 100,  // 5% slippage tolerance
            (ethAmount * 95) / 100,
            msg.sender,
            block.timestamp + 600
        );

        console.log("\n=== LIQUIDITY ADDED ===");
        console.log("RUB deposited:", amountToken / 1e18);
        console.log("ETH deposited:", amountETH / 1e18);
        console.log("LP tokens received:", liquidity);
        console.log("========================");

        vm.stopBroadcast();

        // Print final summary
        address pair = factory.getPair(wethAddr, rubToken);
        console.log("\n=== FINAL SUMMARY ===");
        console.log("WETH:  ", wethAddr);
        console.log("RUB:   ", rubToken);
        console.log("Pair:  ", pair);
        console.log("Router:", routerAddr);
        console.log("======================");
        console.log("\nSwap is now live! Update your frontend .env.local:");
        console.log("  NEXT_PUBLIC_UNISWAP_V2_ROUTER=", vm.toString(routerAddr));
        console.log("  NEXT_PUBLIC_RUBBI_TOKEN_ADDRESS=", vm.toString(rubToken));
    }
}
