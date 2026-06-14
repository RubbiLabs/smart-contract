// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import "../src/interfaces/IUniswapV2.sol";
import "../src/WETH9.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Creates WETH/RUB and ARB/RUB pairs on Uniswap V2 and adds initial liquidity.
///
/// Run AFTER DeploySwap.s.sol:
///   forge script script/SetupPair.s.sol --rpc-url <RPC> --broadcast --verify
///
/// Environment variables:
///   PRIVATE_KEY           — deployer private key
///   UNISWAP_V2_FACTORY    — factory address from DeploySwap
///   UNISWAP_V2_ROUTER     — router address from DeploySwap
///   RUBBI_TOKEN_ADDRESS   — RUB token address
///   WETH_ADDRESS          — WETH address
///   ARB_ADDRESS           — ARB token address on Arbitrum Sepolia
///
///   LIQUIDITY_RUB         — RUB for WETH/RUB pair (default: 320000 ether)
///   LIQUIDITY_ETH_WEI     — ETH for WETH/RUB pair (default: 100 ether)
///   LIQUIDITY_RUB_ARB     — RUB for ARB/RUB pair (default: 320000 ether)
///   LIQUIDITY_ARB_WEI     — ARB for ARB/RUB pair (default: 100000 ether)
///

contract SetupPairScript is Script {
    function run() public {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address factoryAddr = vm.envAddress("UNISWAP_V2_FACTORY");
        address routerAddr = vm.envAddress("UNISWAP_V2_ROUTER");
        address rubToken = vm.envAddress("RUBBI_TOKEN_ADDRESS");
        address wethAddr = vm.envAddress("WETH_ADDRESS");
        address arbAddr = vm.envAddress("ARB_ADDRESS");

        uint256 rubAmount = vm.envOr("LIQUIDITY_RUB", uint256(320_000 ether));
        uint256 ethAmount = vm.envOr("LIQUIDITY_ETH_WEI", uint256(100 ether));
        uint256 rubAmountArb = vm.envOr("LIQUIDITY_RUB_ARB", uint256(320_000 ether));
        uint256 arbAmount = vm.envOr("LIQUIDITY_ARB_WEI", uint256(100_000 ether));

        IUniswapV2Factory factory = IUniswapV2Factory(factoryAddr);
        IUniswapV2Router02 router = IUniswapV2Router02(routerAddr);

        vm.startBroadcast(privateKey);

        // ═══════════════════════════════════════════════════════
        // PAIR 1: WETH / RUB
        // ═══════════════════════════════════════════════════════
        console.log("=== PAIR 1: WETH / RUB ===");

        address wethRubPair = factory.getPair(wethAddr, rubToken);
        if (wethRubPair == address(0)) {
            console.log("Creating WETH/RUB pair...");
            wethRubPair = factory.createPair(wethAddr, rubToken);
            console.log("Pair created at:", wethRubPair);
        } else {
            console.log("WETH/RUB pair already exists at:", wethRubPair);
        }

        // Approve and add liquidity for WETH/RUB
        IERC20(rubToken).approve(routerAddr, rubAmount);

        (uint256 amountToken1, uint256 amountETH1, uint256 liquidity1) = router.addLiquidityETH{value: ethAmount}(
            rubToken,
            rubAmount,
            (rubAmount * 95) / 100,
            (ethAmount * 95) / 100,
            msg.sender,
            block.timestamp + 600
        );

        console.log("WETH/RUB liquidity added:");
        console.log("  RUB:", amountToken1 / 1e18);
        console.log("  ETH:", amountETH1 / 1e18);
        console.log("  LP:", liquidity1);

        // ═══════════════════════════════════════════════════════
        // PAIR 2: ARB / RUB
        // ═══════════════════════════════════════════════════════
        console.log("\n=== PAIR 2: ARB / RUB ===");

        address arbRubPair = factory.getPair(arbAddr, rubToken);
        if (arbRubPair == address(0)) {
            console.log("Creating ARB/RUB pair...");
            arbRubPair = factory.createPair(arbAddr, rubToken);
            console.log("Pair created at:", arbRubPair);
        } else {
            console.log("ARB/RUB pair already exists at:", arbRubPair);
        }

        // Approve and add liquidity for ARB/RUB
        // Deployer needs ARB tokens. On Arbitrum Sepolia, ARB can be obtained from faucet.
        // Ratio: 1 ARB = 3.2 RUB (at ARB = $1, RUB = $0.02)
        IERC20(rubToken).approve(routerAddr, rubAmountArb);
        IERC20(arbAddr).approve(routerAddr, arbAmount);

        (uint256 amountARB, uint256 amountRUB2, uint256 liquidity2) = router.addLiquidity(
            arbAddr,
            rubToken,
            arbAmount,
            rubAmountArb,
            (arbAmount * 95) / 100,
            (rubAmountArb * 95) / 100,
            msg.sender,
            block.timestamp + 600
        );

        console.log("ARB/RUB liquidity added:");
        console.log("  ARB:", amountARB / 1e18);
        console.log("  RUB:", amountRUB2 / 1e18);
        console.log("  LP:", liquidity2);

        vm.stopBroadcast();

        // ═══════════════════════════════════════════════════════
        // FINAL SUMMARY
        // ═══════════════════════════════════════════════════════
        address finalWethRubPair = factory.getPair(wethAddr, rubToken);
        address finalArbRubPair = factory.getPair(arbAddr, rubToken);

        console.log("\n========================================");
        console.log("   ALL PAIRS CREATED");
        console.log("========================================");
        console.log("WETH:       ", wethAddr);
        console.log("RUB:        ", rubToken);
        console.log("ARB:        ", arbAddr);
        console.log("WETH/RUB:   ", finalWethRubPair);
        console.log("ARB/RUB:    ", finalArbRubPair);
        console.log("Router:     ", routerAddr);
        console.log("Factory:    ", factoryAddr);
        console.log("========================================");
        console.log("\nSwap is now live for both ETH and ARB!");
        console.log("Update frontend .env.local:");
        console.log("  NEXT_PUBLIC_UNISWAP_V2_ROUTER=", vm.toString(routerAddr));
        console.log("  NEXT_PUBLIC_RUBBI_TOKEN_ADDRESS=", vm.toString(rubToken));
    }
}
