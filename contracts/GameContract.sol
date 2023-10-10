// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./GameNft.sol";
import "hardhat/console.sol";
/**
 * @title The GameContract contract
 * @notice A contract that lets players play solo or PvP games using their own NFTs.
 * @dev This contract is owned by a user (deployer) who has the ability to update parameters.
 * For every game, a corresponding NFT is minted.
 */
contract GameContract is Ownable {
	using ECDSA for bytes32;

	address public adminAddress;
	address public cryptoCardArenaAddress;
    address public gameNft;
	uint256 public join_price;
	uint256 public rewardPrc;

	struct Game{
		uint256 id;
		address p1_address;
		address p2_address;
		uint256 card1;
		uint256 card2;
		uint256 number;// the random number generated
		uint8 g_type;// 1 => solo, 2 => pvp
		uint8 caracter;//0 => NONE, 1 => < , 2 => >
		uint8 winner; // 1 => p1 , 2 => p2
		uint256 reward;
		uint256 date;
	}

	struct UserGameStats {
        uint256 totalWin;
		uint256 sologames;
		uint256 pvpgames;
		uint256 rewards;
		uint256[] games;
	}

	uint256[] public liveGames;
	mapping(address => UserGameStats) public userStats;
	mapping(uint256 => Game) public games;

	uint256 public totalGames;

    /**
     * @notice Event emitted when a solo game is initiated
     * @param gameId The unique id of the game
     * @param user The address of the player
     * @param random The generated random number
     * @param winner The winner of the game (1 for player, 2 for opponent or player2)
     */
    event NewSoloGame(uint256 gameId,address user,uint256 random,uint8 winner);
    event NewPvPGame(uint256 gameId,address user);
    event PvPGame(uint256 gameId,uint256 random,address _winner);

	modifier isCardOwner(uint256 _cardId){
		require(IERC721(cryptoCardArenaAddress).ownerOf(_cardId) == msg.sender,"You are not the acrd owner");
		_;
	}

    /**
     * @notice Constructor function that sets initial admin, arena, join price and reward percentage
     * @param _admin The address of the admin
     * @param _arena The address of the arena (the NFT contract)
     * @param _price The join price for a game
     * @param _rewardPrc The percentage of the reward to be given to the winner
     */
    constructor(address _admin,address _arena,uint256 _price,uint256 _rewardPrc) {
		adminAddress = _admin;
		cryptoCardArenaAddress = _arena;
		gameNft = address(new GameNft());
		join_price = _price;
		rewardPrc = _rewardPrc;
    }

    /**
     * @notice Play a solo game
     * @dev Requires a valid signature from the admin for the game inputs
     * @param _cardId The id of the card (NFT) the player is using
     * @param _score The score of the player
     * @param _caracter The chosen character (1 for <, 2 for >)
     * @param _signature The signature from the admin
     * @return gameID The unique id of the game
     * @return _winner The winner of the game (1 for player, 2 for opponent)
     * @return random_score The generated random score
     */
	function playSolo(uint256 _cardId,uint256 _score,uint8 _caracter,bytes memory _signature) external payable isCardOwner(_cardId) returns(uint256 gameID,uint8 _winner,uint256 random_score) {
       
	    require(msg.value >= join_price,"Invalid Amount");
	    bytes32 msgHash = keccak256(
            abi.encodePacked("PlaySolo(",_cardId,_score,msg.sender,_caracter,")")
        );
        
        /// @dev here we validate that the admin put the score to the inputs of playingSolo function
        require(_validSignature(_signature, msgHash), "INVALID_SIGNATURE");
		gameID = totalGames;
        random_score = uint256(keccak256(abi.encodePacked(gameID,msg.sender,block.coinbase, block.timestamp))) % 200 + 1;
		if((_caracter == 1 && _score < random_score) ||(_caracter == 1 && _score < random_score) ) {
			_winner = 1;
			userStats[msg.sender].totalWin +=1;
			userStats[msg.sender].sologames +=1;
			userStats[msg.sender].rewards = (msg.value*rewardPrc)/1000;
		}
		else _winner = 2;
		games[gameID] = Game(gameID,msg.sender,address(0),_cardId,0,random_score,1,_caracter,_winner,msg.value,block.timestamp);
		userStats[msg.sender].games.push(gameID);
		totalGames+=1;
		GameNft(gameNft).mintNft(gameID,msg.sender,_winner==1);   
		emit NewSoloGame(gameID,msg.sender,random_score,_winner);
	}

    /**
     * @notice Initiate a PvP game
     * @dev Requires a valid signature from the admin for the game inputs
     * @param _cardId The id of the card (NFT) the player is using
     * @param _score The score of the player
     * @param _signature The signature from the admin
     * @return gameID The unique id of the game
     */
	function playPVP(uint256 _cardId,uint256 _score,bytes memory _signature) external payable isCardOwner(_cardId) returns(uint256 gameID){
       
	    require(msg.value >= join_price,"Invalid Amount");
	    bytes32 msgHash = keccak256(
            abi.encodePacked("PlayPVP(",_cardId,_score,msg.sender,")")
        );
        
        /// @dev here we validate that the admin put the score to the inputs of playingPVP function
        require(_validSignature(_signature, msgHash), "INVALID_SIGNATURE");
	    gameID = totalGames;
		userStats[msg.sender].pvpgames +=1;
		liveGames.push(gameID);
		games[gameID] = Game(gameID,msg.sender,address(0),_cardId,0,_score,2,0,0,msg.value,block.timestamp);
		userStats[msg.sender].games.push(gameID);
		totalGames+=1;
		emit NewPvPGame(gameID,msg.sender);

	}

    /**
     * @notice Join an existing game
     * @dev Requires a valid signature from the admin for the game inputs
     * @param _gameId The id of the game to join
     * @param _cardId The id of the card (NFT) the player is using
     * @param _score The score of the player
     * @param _signature The signature from the admin
     * @return _winner The winner of the game (1 for player 1, 2 for player 2)
     * @return random_score The generated random score
     */
	function joinGame(uint256 _gameId,uint256 _cardId,uint256 _score,bytes memory _signature) external payable isCardOwner(_cardId) returns(uint8 _winner,uint256 random_score){
       	(uint256 index,bool _found) = getLiveIndex(_gameId);
	   	require(games[_gameId].p1_address != address(0) && _found,"Live Game not found");
	    require(msg.value >= join_price,"Invalid Amount");
	    bytes32 msgHash = keccak256(
            abi.encodePacked("PlayPVP2(",_gameId,_cardId,_score,msg.sender,")")
        );
        /// @dev here we validate that the admin put the score to the inputs of playingPVP2 function
        require(_validSignature(_signature, msgHash), "INVALID_SIGNATURE");
         random_score = uint256(keccak256(abi.encodePacked(_gameId,msg.sender,block.coinbase, block.timestamp))) % 200 + 1;
		_winner = (getClosestValue(games[_gameId].number,_score,random_score)== _score)? 2:1;
		userStats[msg.sender].games.push(_gameId);
		userStats[msg.sender].pvpgames +=1;
		games[_gameId].p2_address = msg.sender;
		games[_gameId].card2 = _cardId;
		games[_gameId].number = random_score;
		games[_gameId].reward += msg.value;
		games[_gameId].winner = _winner;
		address _winnerAddress = (_winner == 1)?games[_gameId].p1_address:games[_gameId].p2_address;
		userStats[_winnerAddress].totalWin +=1;
		userStats[_winnerAddress].rewards = (games[_gameId].reward*rewardPrc)/1000;
		removeLiveGame(index);
		emit PvPGame(_gameId,random_score,_winnerAddress);
	}

    /**
     * @notice Claim the pending rewards of the caller
     * @dev Transfers the pending rewards to the caller
     */
	function claimRewards() external {
		uint256 rewards = userStats[msg.sender].rewards;
		require(rewards >0,"No Rewards");
		(bool result,) = payable(msg.sender).call{value:rewards}("");
        require(result,"Transfer Error");
	}

    /**
     * @notice Claim the NFT rewards for a specific game
     * @dev Mints a new NFT for the caller related to the specified game
     * @param _gameId The id of the game
     */
	function claimNftRewards(uint256 _gameId) external {
            GameNft(gameNft).mintNft(_gameId,msg.sender,true);  
	}

    /**
     * @notice Owner can withdraw all accumulated Ether from the contract
     */
	function withdrawEth() external onlyOwner{
		(bool result,) = payable(owner()).call{value:address(this).balance}("");
        require(result,"Transfer Error");
	}


	 /// @dev Checks if a given signature is valid for a specific message hash and signer address.
    /// @param signature The signature to be verified.
    /// @param msgHash The hash of the message that was signed.
    /// @return True if the signature is valid, false otherwise.
    function _validSignature(bytes memory signature, bytes32 msgHash) internal view returns (bool) {
        return msgHash.toEthSignedMessageHash().recover(signature) == adminAddress;
    }

    /**
    * @dev Function to find the closest value between _a and _b to _n
    * @param _a The first number
    * @param _b The second number
    * @param _n The number to compare _a and _b to
    * @return The closest value to _n
    */
    function getClosestValue(uint256 _a, uint256 _b, uint256 _n) internal pure returns (uint256) {
        uint256 diffA = _a > _n ? _a - _n : _n - _a;
        uint256 diffB = _b > _n ? _b - _n : _n - _b;

        if (diffA < diffB) {
            return _a;
        } else {
            return _b;
        }
    }

    /**
    * @notice Returns all games played by a user
    * @param _user The address of the user
    * @return _games Array of games played by the user
    */
    function getUserGames(address _user) external view returns(Game[] memory _games) {
        _games = new Game[](userStats[_user].games.length);
        
        for (uint i = 0; i < userStats[_user].games.length; i++) {
            _games[i] = games[userStats[_user].games[i]];
        }
    }

    /**
    * @notice Returns all live games
    * @return _games Array of live games
    */
    function getLiveGames() external view returns(Game[] memory _games) {
        _games = new Game[](liveGames.length);
        
        for(uint i=0 ; i< liveGames.length; i++){
            _games[i] = games[liveGames[i]];
        }
    }

    /**
    * @notice Updates the address of the admin
    * @param _admin The new admin address
    */
    function updateAdminAddress(address _admin) external onlyOwner {
        adminAddress = _admin;
    }

    /**
    * @notice Updates the addresses of the arena and game NFT contracts
    * @param _arena The new arena address
    * @param _gameNft The new game NFT contract address
    */
    function updateContractAddress(address _arena, address _gameNft) external onlyOwner {
        cryptoCardArenaAddress = _arena;
        gameNft = _gameNft;
    }

    /**
    * @notice Updates the join price and reward percentage
    * @param _join_p The new join price
    * @param _reward_prc The new reward percentage
    */
    function updateParams(uint256 _join_p, uint256 _reward_prc) external onlyOwner {
        join_price = _join_p;
        rewardPrc = _reward_prc;
    }

    /**
    * @dev Finds the index of a live game
    * @param value The id of the game
    * @return The index and a boolean indicating if the game is found
    */
    function getLiveIndex(uint256 value) internal view returns (uint256, bool) {
        for (uint256 i = 0; i < liveGames.length; i++) {
            if (liveGames[i] == value) {
                return (i, true);
            }
        }
        return (0, false);
    }

    /**
    * @dev Removes a live game from the array of live games
    * @param gameIndex The index of the game to remove
    */
    function removeLiveGame(uint256 gameIndex) internal {
        liveGames[gameIndex] = liveGames[liveGames.length - 1];
        liveGames.pop();
    }
}