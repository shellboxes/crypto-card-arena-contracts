// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {

    subscriptionId = 2495
	vrfCoordinator = "0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625"
    keyHash = "0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c"
    priceFeed = "0xc59E3633BAAC79493d908e63626716e204A45EdF"
	cardIds = Array.from({ length: 200 }, (_, index) => index + 1);
	mint_price = 2
    CryptoCardArena = await hre.ethers.getContractFactory("CryptoCardArena");
    ICryptoCardArena = await CryptoCardArena.deploy(subscriptionId,vrfCoordinator,keyHash,priceFeed,cardIds,mint_price);

    await ICryptoCardArena.deployed();

  console.log(
    `ICryptoCardArena deployed to ${ICryptoCardArena.address}`
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
