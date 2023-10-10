const { expect } = require("chai");
const { ethers,network } = require("hardhat");
const crypto = require("crypto");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers")
const { networkConfig, developmentChains } = require("../helper-hardhat-config")

const deployContractWithParams = async function (deployer,contractName, constructorArgs) {
	let factory = await ethers.getContractFactory(contractName);
  let contract = await factory.connect(deployer).deploy(...(constructorArgs || []));
  await contract.deployed();
  return contract;
  };

const signMsg = async function(signer,msg){
	// Sign the string message
    flatSig = await signer.signMessage(ethers.utils.arrayify(msg));
	return flatSig
}

const randomHex =  function (n){
	var id = crypto.randomBytes(n).toString('hex');
    return "0x"+id

}

const faucet = async function(address, provider)  {
	const BALANCE = ethers.utils.parseEther("100000").toHexString().replace("0x0", "0x");
	await provider.send("hardhat_setBalance", [address, BALANCE]);
  };

describe("GameContract Tests",async function () {
    

	async function deployCryptoCardArenaFixture() {
		[deployer] = await ethers.getSigners()


		/**
		 * @dev Read more at https://docs.chain.link/docs/chainlink-vrf/
		 */
		const BASE_FEE = "100000000000000000"
		const GAS_PRICE_LINK = "1000000000" // 0.000000001 LINK per gas

		const chainId = network.config.chainId

		const VRFCoordinatorV2MockFactory = await ethers.getContractFactory(
			"VRFCoordinatorV2Mock"
		)
		const VRFCoordinatorV2Mock = await VRFCoordinatorV2MockFactory.deploy(
			BASE_FEE,
			GAS_PRICE_LINK
		)

		const fundAmount = networkConfig[chainId]["fundAmount"] || "1000000000000000000"
		const transaction = await VRFCoordinatorV2Mock.createSubscription()
		const transactionReceipt = await transaction.wait(1)
		const subscriptionId = ethers.BigNumber.from(transactionReceipt.events[0].topics[1])
		await VRFCoordinatorV2Mock.fundSubscription(subscriptionId, fundAmount)

		const vrfCoordinatorAddress = VRFCoordinatorV2Mock.address
		const keyHash =
			networkConfig[chainId]["keyHash"] ||
			"0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc"
		
		const DECIMALS = "18"
		const INITIAL_PRICE = "200000000000000000000"
	
		const mockV3AggregatorFactory = await ethers.getContractFactory("MockV3Aggregator")
		const mockV3Aggregator = await mockV3AggregatorFactory
				.connect(deployer)
				.deploy(DECIMALS, INITIAL_PRICE)

		const cryptoCardArenaFactory = await ethers.getContractFactory("CryptoCardArena");
        const cardIds = Array.from({ length: 200 }, (_, index) => index + 1);
		const mint_price = 2
		const cryptoCardArena = await cryptoCardArenaFactory
				   .connect(deployer)
				   .deploy(subscriptionId, vrfCoordinatorAddress, keyHash,mockV3Aggregator.address,cardIds,mint_price)
 
		await VRFCoordinatorV2Mock.addConsumer(subscriptionId, cryptoCardArena.address)
		return { cryptoCardArena, VRFCoordinatorV2Mock ,mockV3Aggregator}
	}

	const { provider } = ethers;
	
    
    beforeEach('Create Instance',async function () {

		const fixture = await loadFixture(deployCryptoCardArenaFixture);
		cryptoCardArena = fixture.cryptoCardArena;

		owner = new ethers.Wallet(randomHex(32),provider);
		admin = new ethers.Wallet(randomHex(32),provider);
		user1 = new ethers.Wallet(randomHex(32),provider);
		user2 = new ethers.Wallet(randomHex(32),provider);

		await Promise.all(
			[owner,admin,user1,user2,user2].map((wallet) => faucet(wallet.address, provider))
		  );

		price = ethers.utils.parseUnits("10",18)
		
		IGameContract =  await deployContractWithParams(owner,'GameContract',[admin.address,cryptoCardArena.address,price,2])
        gameNftAddress = await IGameContract.gameNft()
		IGameNft = await ethers.getContractAt("GameNft", gameNftAddress);


	  });
	
	  after(async () => {
		await network.provider.request({
		  method: "hardhat_reset",
		});
	  });
    it("Should verify GameContract Instance", async function (){
		expect(await IGameContract.adminAddress()).to.be.equal(admin.address)
		expect(await IGameContract.cryptoCardArenaAddress()).to.be.equal(cryptoCardArena.address)
		expect(await IGameContract.join_price()).to.be.equal(price)
		expect(await IGameContract.rewardPrc()).to.be.equal(2)
	});
	it("Should verify GameNft Instance", async function (){
		expect(await IGameNft.gameContract()).to.be.equal(IGameContract.address)
	});

	it("Should play solo", async function (){
		await cryptoCardArena.connect(user1).mintRandCard({value:ethers.utils.parseEther('2')})
        cardId =  await cryptoCardArena.userCards(user1.address,0)	
		score = 20
		caracter = 1 // <
		msg = ethers.utils.solidityKeccak256(
			["string","uint256","uint256","address","uint8","string"],
			["PlaySolo(",
			cardId,
			  score,
			  user1.address,
			  caracter,
			 ")"]
			);
		sig = await signMsg(admin,msg);

		tx  = await IGameContract.connect(user1).playSolo(cardId,score,caracter,sig, {
			value: price
		})

		 receipt = await tx.wait();

		 decodedData = ethers.utils.defaultAbiCoder.decode(["uint256","address","uint256", "uint8"], receipt.events.find((event) => event.event === "NewSoloGame").data);
	  
		 gameID = decodedData[0];
		 user = decodedData[1];
		 random = decodedData[2];
		 _winner = decodedData[3];
         console.log("random = ",random)
		 console.log("is_winner = ",_winner==1)
		if(_winner == 1) {
			expect(await IGameNft.balanceOf(user1.address)).to.be.equal(1)

		}
		expect(user).to.be.equal(user1.address)
		expect(await IGameContract.totalGames()).to.be.equal(gameID.add(1))

		game = await IGameContract.games(gameID)
		expect(game.g_type).to.be.equal(1)
		expect(game.reward).to.be.equal(price)
		expect(game.winner).to.be.equal(_winner)
		expect(game.p1_address).to.be.equal(user1.address)
		expect(game.card1).to.be.equal(cardId)	

		stats = await IGameContract.userStats(user1.address)

		if(stats.rewards>0) await IGameContract.connect(user1).claimRewards()
		else await expect(IGameContract.connect(user1).claimRewards()).to.be.revertedWith("No Rewards");


	});
	
	it("Should play pvp", async function (){
		await cryptoCardArena.connect(user1).mintRandCard({value:ethers.utils.parseEther('2')})
        cardId =  await cryptoCardArena.userCards(user1.address,0)	
		score = 20
		msg = ethers.utils.solidityKeccak256(
			["string","uint256","uint256","address","string"],
			["PlayPVP(",
			  cardId,
			  score,
			  user1.address,
			 ")"]
			);
		sig = await signMsg(admin,msg);

		tx  = await IGameContract.connect(user1).playPVP(cardId,score,sig, {
			value: price
		})

		 receipt = await tx.wait();

		 decodedData = ethers.utils.defaultAbiCoder.decode(["uint256","address"], receipt.events.find((event) => event.event === "NewPvPGame").data);
	  
		 gameID = decodedData[0];
		 user = decodedData[1];
		expect(user).to.be.equal(user1.address)
		expect(await IGameContract.totalGames()).to.be.equal(gameID.add(1))

		game = await IGameContract.games(gameID)
		expect(game.g_type).to.be.equal(2)
		expect(game.reward).to.be.equal(price)
		expect(game.p1_address).to.be.equal(user1.address)
		expect(game.card1).to.be.equal(cardId)	

		await cryptoCardArena.connect(user2).mintRandCard({value:ethers.utils.parseEther('2')})
        cardId =  await cryptoCardArena.userCards(user2.address,0)	
		score = 43
		msg = ethers.utils.solidityKeccak256(
			["string","uint256","uint256","uint256","address","string"],
			["PlayPVP2(",
			  gameID,
			  cardId,
			  score,
			  user2.address,
			 ")"]
			);
		sig = await signMsg(admin,msg);

		tx  = await IGameContract.connect(user2).joinGame(gameID,cardId,score,sig, {
			value: price
		})

		 receipt = await tx.wait();

		 decodedData = ethers.utils.defaultAbiCoder.decode(["uint256","uint256","address"], receipt.events.find((event) => event.event === "PvPGame").data);
	  
		 gameID = decodedData[0];
		 random = decodedData[1];
		 winner = decodedData[2];
		 console.log("random =",random)
		 game = await IGameContract.games(gameID)
		 expect(game.g_type).to.be.equal(2)
		 expect(game.reward).to.be.equal(price.mul(2))
		 expect(game.p2_address).to.be.equal(user2.address)
		 expect(game.card2).to.be.equal(cardId)	

		 if(winner == user1.address )   expect(game.winner).to.be.equal(1)
		 else expect(game.winner).to.be.equal(2)

   		expect(await IGameContract.totalGames()).to.be.equal(gameID.add(1))

	});
});
