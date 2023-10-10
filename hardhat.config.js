require("@nomicfoundation/hardhat-toolbox");
require('solidity-coverage')
require('hardhat-docgen');
require("dotenv").config();

const COMPILER_SETTINGS = {
    optimizer: {
        enabled: true,
        runs: 1000000,
    },
    metadata: {
        bytecodeHash: "none",
    },
}
/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
	solidity: {
        compilers: [
			{
                version: "0.8.19",
                COMPILER_SETTINGS,
            },
            {
                version: "0.8.7",
                COMPILER_SETTINGS,
            },
            {
                version: "0.6.6",
                COMPILER_SETTINGS,
            },
            {
                version: "0.4.24",
                COMPILER_SETTINGS,
            },
        ],
    },
  defaultNetwork: "hardhat",
  networks: {
	hardhat: {
		hardfork: "merge",
		// If you want to do some forking set `enabled` to true
		forking: {
			url: "https://rpc2.sepolia.org",
			enabled: false,
		},
		chainId: 31337,
	},
	localhost: {
		chainId: 31337,
	},
	sepolia: {
		url: 'https://rpc2.sepolia.org',
		accounts: [process.env.DEPLOYER_PRIVATE_KEY],
		chainId: 11155111,
	  }
  },
  settings: {
    optimizer: {
      enabled: true,
      runs: 200,
    //   details: { yul: false },
    },
  },
  docgen: {
	path: './docs',
	clear: true,
	runOnCompile: true,
  },
  etherscan: {
    // Your API key for Etherscan
    // Obtain one at https://etherscan.io/
    apiKey: {
		mainnet:process.env.ETHERSCAN_API_KEY,
        goerli:process.env.ETHERSCAN_API_KEY,
		sepolia:process.env.ETHERSCAN_API_KEY
		}
  }
};
