// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {

  admin = "0xE369B3332Fe1a6e205488384725F8b4823e6D668"
  arena = "0xCc3e5bD323DB6363ACa975310f8eb25fdC378DBc"
  price = ethers.utils.parseUnits("10",4)
  prc = 2
  GameContract = await hre.ethers.getContractFactory("GameContract");
  IGameContract = await GameContract.deploy(admin,arena,price,prc);

  await IGameContract.deployed();

  console.log(
    `IGameContract deployed to ${IGameContract.address}`
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
