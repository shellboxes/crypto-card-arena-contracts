const { assert,expect } = require("chai");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers")
const { network } = require("hardhat");
const { networkConfig, developmentChains } = require("../helper-hardhat-config")

describe("CryptoCardArena",async function () {


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
  beforeEach(async function () {
	 [deployer,user1] = await ethers.getSigners()

	 const fixture = await loadFixture(deployCryptoCardArenaFixture);
     cryptoCardArena = fixture.cryptoCardArena;
     VRFCoordinatorV2Mock = fixture.VRFCoordinatorV2Mock;
     mockV3Aggregator = fixture.mockV3Aggregator;
  });

describe("deployment", async function () {
	describe("success", async function () {
		it("should set the aggregator addresses correctly", async () => {
			const response = await cryptoCardArena.getPriceFeed()
			assert.equal(response, mockV3Aggregator.address)
		})
	})
})

describe("#getLatestPrice", async function () {
	describe("success", async function () {
		it("should return the same value as the mock", async () => {
			const priceConsumerResult = await cryptoCardArena.getLatestPrice()
			const priceFeedResult = (await mockV3Aggregator.latestRoundData()).answer
			assert.equal(priceConsumerResult.toString(), priceFeedResult.toString())
		})
	})
})

describe("#mintCard", async function () {
	describe("success", async function () {
		it("Should successfully request a random number and get a result", async function () {
			await cryptoCardArena.connect(user1).mintCard({value:ethers.utils.parseUnits('2',5)})
			 requestId = await cryptoCardArena.s_requestId()
      
			assert(
				requestId.gt(ethers.constants.Zero),
				"request id exists"
			)
			expect(await cryptoCardArena.requestUsers(requestId)).to.equal(user1.address);

			// simulate callback from the oracle network
			await expect(
				VRFCoordinatorV2Mock.fulfillRandomWords(
					requestId,
					cryptoCardArena.address
				)
			).to.emit(cryptoCardArena, "ReturnedRandomness")



		})

		it("Should successfully fire event on callback and mint random card", async function () {
        initialAvailableCardsLength = await cryptoCardArena.availableCardsLength();
		assert(initialAvailableCardsLength.eq(200))
        user1Cards = await cryptoCardArena.balanceOf(user1.address);
        expect(user1Cards).to.equal(0);
			await new Promise(async (resolve, reject) => {
				cryptoCardArena.once("ReturnedRandomness", async (user,cardId) => {
					console.log("ReturnedRandomness event fired ! cardId = ",cardId)
					 balanceUser = await cryptoCardArena.balanceOf(user1.address)
					 cardOwner = await cryptoCardArena.ownerOf(cardId)
					  // Get the final available cards length
                    finalAvailableCardsLength = await cryptoCardArena.availableCardsLength();
					// assert throws an error if it fails, so we need to wrap
					// it in a try/catch so that the promise returns event
					// if it fails.
					try {
						expect(await cryptoCardArena.isCardAvailabe(cardId)).to.be.false;
						expect(user).to.equal(user1.address);

						expect(cardOwner).to.equal(user1.address);
						assert(balanceUser.eq(1))
						assert(finalAvailableCardsLength.eq(initialAvailableCardsLength.sub(1)))
						resolve()
					} catch (e) {
						reject(e)
					}
				})
				await cryptoCardArena.connect(user1).mintCard({value:ethers.utils.parseUnits('2',5)})
				requestId = await cryptoCardArena.s_requestId()
				VRFCoordinatorV2Mock.fulfillRandomWords(
					requestId,
					cryptoCardArena.address
				)
			})
		})
	})

	describe("revert", async function () {
		it("Should revert when invalid amount", async function () {
			await expect( cryptoCardArena.connect(user1).mintCard( {
				value: ethers.utils.parseUnits('10',0)
			})).to.be.revertedWith("Insufficient ether sent");

		})

	})
})

describe("#token uri", async function () {
	describe("success", async function () {
		it("Should successfully set the base uri", async function () {
			baseURi = "test/"
			await cryptoCardArena.setBaseURI(baseURi)
			expect(await cryptoCardArena.baseURI()).to.equal(baseURi);

		})

		it("Should successfully get the minted token uri", async function () {
			    baseURi = "test/"
			    await cryptoCardArena.setBaseURI(baseURi)

    			await new Promise(async (resolve, reject) => {
				cryptoCardArena.once("ReturnedRandomness", async (user,cardId) => {
					console.log("ReturnedRandomness event fired")
					// assert throws an error if it fails, so we need to wrap
					// it in a try/catch so that the promise returns event
					// if it fails.
					try {
						expect(await cryptoCardArena.tokenURI(cardId)).to.equal(baseURi+'card_'+cardId+'.json');
						resolve()
					} catch (e) {
						reject(e)
					}
				})
				await cryptoCardArena.connect(user1).mintCard({value:ethers.utils.parseUnits('2',5)})
				requestId = await cryptoCardArena.s_requestId()
				VRFCoordinatorV2Mock.fulfillRandomWords(
					requestId,
					cryptoCardArena.address
				)
			})
		})
	})
	describe("revert", async function () {
		it("Should revert when user1 want to set baseUri", async function () {
			baseURi = "test/"
			await expect( cryptoCardArena.connect(user1).setBaseURI(baseURi)).to.be.revertedWith("Ownable: caller is not the owner");

		})
	})
})
});