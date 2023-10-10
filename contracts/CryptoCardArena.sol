// SPDX-License-Identifier: MIT
// An example of a consumer contract that relies on a subscription for funding.
pragma solidity 0.8.19;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "hardhat/console.sol";

/**
 * @title The RandomNumberConsumerV2 contract
 * @notice A contract that handle the minting logic of nftCard
 */
contract CryptoCardArena is ERC721, Ownable, VRFConsumerBaseV2 {

    using Strings for uint256;

    VRFCoordinatorV2Interface private COORDINATOR;
    AggregatorV3Interface private priceFeed;

    // Your subscription ID.
    uint64 private s_subscriptionId;

    // The gas lane to use, which specifies the maximum gas price to bump to.
    // For a list of available gas lanes on each network,
    // see https://docs.chain.link/docs/vrf-contracts/#configurations
    bytes32 private s_keyHash;

    // Depends on the number of requested values that you want sent to the
    // fulfillRandomWords() function. Storing each word costs about 20,000 gas,
    // so 100,000 is a safe default for this example contract. Test and adjust
    // this limit based on the network that you select, the size of the request,
    // and the processing of the callback request in the fulfillRandomWords()
    // function.
    uint32 constant CALLBACK_GAS_LIMIT = 100000;

    // The default is 3, but you can set this higher.
    uint16 constant REQUEST_CONFIRMATIONS = 3;

    // For this example, retrieve 2 random values in one request.
    // Cannot exceed VRFCoordinatorV2.MAX_NUM_WORDS.
    uint32 constant NUM_WORDS = 1;

    uint256[] private availableCards;
    uint256 public s_requestId;
    mapping(uint256 => address) public requestUsers;
    mapping(address => uint256[]) public userCards;

    /// @notice The mint price in LINK
    uint256 public mintPrice;
    /// @notice The base URI for token metadata
    string public baseURI;

    event ReturnedRandomness(address user, uint256 cardId);
    event RandomIdRequested(uint256 requestId);

    /**
     * @notice Constructor inherits VRFConsumerBaseV2
     *
     * @param subscriptionId - the subscription ID that this contract uses for funding requests
     * @param vrfCoordinator - coordinator, check https://docs.chain.link/docs/vrf-contracts/#configurations
     * @param keyHash - the gas lane to use, which specifies the maximum gas price to bump to
     * @param _priceFeed - Price Feed Address
     * @param cardIds - All card Ids Available 
     * @param mint_price - Mint price in LINK
     */
    constructor(
        uint64 subscriptionId,
        address vrfCoordinator,
        bytes32 keyHash,
        address _priceFeed,
        uint256[] memory cardIds,
        uint256 mint_price
    ) ERC721("CryptoCardArena", "CCA") VRFConsumerBaseV2(vrfCoordinator) {
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        s_keyHash = keyHash;
        s_subscriptionId = subscriptionId;
        availableCards = cardIds;
        priceFeed = AggregatorV3Interface(_priceFeed);
        mintPrice = mint_price;
    }

    /**
     * @notice Mint a random card
     * @dev Sends a request to Chainlink VRF to get a random number
     */
    function mintCard() external payable {
        require(availableCards.length > 0, "No available cards");
        uint256 price = getMintPriceValue()/1e18;
        require(msg.value >= price, "Insufficient ether sent");
        // Request randomness from Chainlink VRF & Store the requestId for later reference
        uint256 requestId = COORDINATOR.requestRandomWords(
            s_keyHash,
            s_subscriptionId,
            REQUEST_CONFIRMATIONS,
            CALLBACK_GAS_LIMIT,
            NUM_WORDS
        );
        s_requestId = requestId;
        requestUsers[requestId] = msg.sender;
        emit RandomIdRequested(requestId);
    }

    /**
     * @notice Mint a random card without Chainlink VRF
     */
    function mintRandCard() external payable {
        require(availableCards.length > 0, "No available cards");
        uint256 randomIndex = uint256(keccak256(abi.encodePacked(msg.sender, block.coinbase, block.timestamp)))  % availableCards.length;
        _mintUserCard(msg.sender, randomIndex);
    }

    /**
     * @notice Internal function to mint a card to a user
     * @param _user The address of the user
     * @param randomIndex The index of the card to mint
     * @return The id of the minted card
     */
    function _mintUserCard(address _user, uint256 randomIndex) internal returns(uint256) {
        uint256 cardId = availableCards[randomIndex];
        availableCards[randomIndex] = availableCards[availableCards.length - 1];
        availableCards.pop();
        userCards[_user].push(cardId);
        _safeMint(_user, cardId);
        return cardId;
    }

    /**
     * @notice Callback function used by VRF Coordinator
     * @param requestId The id of the request
     * @param randomWords The array of random results from VRF Coordinator
     */
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        uint256 randomIndex = randomWords[0] % availableCards.length;
        uint256 cardId = availableCards[randomIndex];
        availableCards[randomIndex] = availableCards[availableCards.length - 1];
        availableCards.pop();
        _safeMint(requestUsers[requestId], cardId);
        emit ReturnedRandomness(requestUsers[requestId], cardId);
    }

    /**
     * @notice Sets the base URI for token metadata
     * @param _baseURI The new base URI
     */
    function setBaseURI(string memory _baseURI) external onlyOwner {
        baseURI = _baseURI;
    }

    /**
     * @notice Gets the mint price in Ether
     * @return The mint price in Ether
     */
    function getMintPriceValue() public view returns (uint256) {
        (, int answer,,,) = priceFeed.latestRoundData();
        require(answer > 0, "Invalid price feed");
        return (mintPrice * uint256(answer));
    }

    /**
     * @notice Returns the Price Feed address
     * @return The price feed address
     */
    function getPriceFeed() public view returns (AggregatorV3Interface) {
        return priceFeed;
    }

    /**
     * @notice Returns the latest price
     * @return The latest price
     */
    function getLatestPrice() public view returns (int256) {
        (, int price,,,) = priceFeed.latestRoundData();
        return price;
    }

    /**
     * @notice Returns the token URI for a given token ID
     * @param tokenId The token ID
     * @return The token URI
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        _requireMinted(tokenId);
        return string(abi.encodePacked(baseURI, 'card_',tokenId.toString(),'.json'));
    }

    /**
     * @notice Checks if a card is available
     * @param tokenId The token ID
     * @return available Whether the card is available
     */
    function isCardAvailabe(uint256 tokenId) external view returns (bool available) {
        for (uint256 i = 0; i < availableCards.length; i++) {
            if (availableCards[i] == tokenId) {
                available = true;
            }
        }
    }

    /**
     * @notice Returns the number of available cards
     * @return The number of available cards
     */
    function availableCardsLength() external view returns (uint256) {
        return availableCards.length;
    }

    /**
     * @notice Returns the cards of a user
     * @param user The user's address
     * @return The cards of the user
     */
    function getUserCards(address user) external view returns (uint256[] memory) {
        return userCards[user];
    }

    /**
     * @notice Updates the available cards
     * @param _cards The new array of available cards
     */
    function updateAvailableCards(uint256[] memory _cards) external onlyOwner {
        availableCards = _cards;
    }

    /**
     * @notice Updates the price feed
     * @param _priceFeed The new price feed
     */
    function updatePriceFeed(address _priceFeed) external onlyOwner {
        priceFeed = AggregatorV3Interface(_priceFeed);
    }

    /**
     * @notice Updates the mint price
     * @param _price The new mint price
     */
    function updateMintPrice(uint256 _price) external onlyOwner {
        mintPrice = _price;
    }

    /**
     * @notice Updates the parameters of the contract
     * @param subscriptionId The new subscription ID
     * @param vrfCoordinator The new VRF Coordinator
     * @param keyHash The new key hash
     */
    function updateParams(uint64 subscriptionId, address vrfCoordinator, bytes32 keyHash) external onlyOwner {
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        s_keyHash = keyHash;
        s_subscriptionId = subscriptionId;
    }
   
}
