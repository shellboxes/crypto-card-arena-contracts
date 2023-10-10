//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./libraries/Base64.sol";

/**
 * @title GameNft Contract
 * @dev This contract creates and manages non-fungible tokens (NFTs) related to a game.
 */
contract GameNft is ERC721{

    using Counters for Counters.Counter;
    using Strings for uint256;
    
    Counters.Counter private _tokenIds;
    
    // The address of the associated game contract
	address public gameContract;

	// Mapping from token ID to game struct
	mapping(uint256 => ArenaGame) public contractNfts;
	
	// Mapping from game ID and user address to token ID
	mapping(uint256 => mapping(address => uint256)) public userGameNfts;

	// Struct representing a game
	struct ArenaGame{
		uint256 gameId;
        address user;
		bool is_winner;
	}

    /**
     * @dev Constructor for the GameNft contract.
     * Sets the name, symbol of the token, and sets the game contract address to the deployer address.
     */
    constructor() ERC721("ArenaGame", "CCAG")  {
       gameContract = msg.sender;
    }
    
    /**
     * @dev Modifier to make a function callable only when it is called by the game contract.
     */
	modifier onlyGameContract(){
		require(msg.sender == gameContract,"Unauthorized");
		_;
	}

	/**
     * @dev Mints an NFT.
     * @param _gameId The ID of the game
     * @param _user The address of the user
     * @param _iswinner A boolean value representing if the user is a winner
     * @return The token ID of the minted NFT
     */
	function mintNft(uint256 _gameId,address _user,bool _iswinner) public onlyGameContract  returns (uint256)
    {
        require(userGameNfts[_gameId][_user] == 0,"Already Minted");
		_tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
		contractNfts[newItemId] = ArenaGame(_gameId,_user,_iswinner);
		userGameNfts[_gameId][_user] = newItemId;
        _safeMint(_user, newItemId);
        return newItemId;
    }

    /**
     * @dev Returns the token URI for a given token ID
     * @param tokenId The token ID
     * @return The token URI
     */
   function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        _requireMinted(tokenId);

    return Base64.encode(
            bytes(string(
                abi.encodePacked(
                    '"attributes": [{"trait_type": "GameId", "value": ', contractNfts[tokenId].gameId.toString(), '},',
					'{"trait_type": "Certificate", "value": ', contractNfts[tokenId].is_winner?"Winner":"Participant", '},',
					'{"trait_type": "User", "value": ', contractNfts[tokenId].user, '}',
                    ']}'
                )
            ))
        );
	}


    /**
     * @dev Hook that is called before any token transfer, including mints and burns.
     * @param from Source address
     * @param to Target address
     * @param firstTokenId ID of the first token being transferred in batch
     * @param batchSize Total number of tokens being transferred
     * @notice This overrides the function in the ERC721 contract to add custom transfer logic.
     */
    function _beforeTokenTransfer(address from, address to, uint256 firstTokenId, uint256 batchSize) internal virtual  override {
        if(from != address(this) && from != address(0) && to != address(0))  revert();
    }

}

