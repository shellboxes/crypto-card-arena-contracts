const delay = ms => new Promise(res => setTimeout(res, ms));

async function main() {
	subscriptionId = 2495
	vrfCoordinator = "0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625"
    keyHash = "0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c"
    priceFeed = "0xc59E3633BAAC79493d908e63626716e204A45EdF"
	cardIds = Array.from({ length: 200 }, (_, index) => index + 1);
	mint_price = 2
	admin = "0xE369B3332Fe1a6e205488384725F8b4823e6D668"
	arena = "0xCc3e5bD323DB6363ACa975310f8eb25fdC378DBc"
	price = ethers.utils.parseUnits("10",4)
	prc = 2
	contracts = [
		{
	    	name:"CryptoCardArena",
            address:"0xCc3e5bD323DB6363ACa975310f8eb25fdC378DBc",
			args:[subscriptionId,vrfCoordinator,keyHash,priceFeed,cardIds,mint_price],
	    },
		{
		    name:"GameContract",
	     	address:"0x7E18c242E9d2D2Ada91C8Dd43A25c0d6F944Af3c",
			 args:[admin,arena,price,prc],
		},
	]
	
	console.log(contracts)
	for await( item of contracts){
	    contract = item.name
	    console.log("------ verify contract "+contract+" --------")
        await hre.run("verify:verify", {
	        address: item.address,
	        contract: "contracts/"+contract+".sol:"+contract,
			constructorArguments : item.args,
         });
		await delay(5000)
	}

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

