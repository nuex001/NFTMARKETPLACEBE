// require("@nomicfoundation/hardhat-toolbox")
require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-ethers"); //had this problem that getContract is always saying ethers.getContract is not a function
require("dotenv").config()
require("solidity-coverage")
require("hardhat-gas-reporter")
require("hardhat-deploy");
require("@nomiclabs/hardhat-etherscan");

/** @type import('hardhat/config').HardhatUserConfig */
const SEPOLIA_RPC_URL =
  process.env.SEPOLIA_RPC_URL ||
  ""
const PRIVATE_KEY =
  process.env.PRIVATE_KEY ||
  ""
const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY || ""

module.exports = {
  solidity: "0.8.18",
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      chainId: 31337,
    },
    sepolia: {
      url: SEPOLIA_RPC_URL,
      accounts: [PRIVATE_KEY],
      chainId: 11155111,
      blockConfirmations: 6, //for verification
    },
  },
  gasReporter: {
    enabled: true,
    outputFile: "gas-report.txt",
    noColors: true,
    currency: "USD",
    // coinmaerketcap:COINMARKET_API_KEY,
    // token:"ETH"
  },
  etherscan: {
    apiKey: ETHERSCAN_API_KEY,
  },
  namedAccounts: {
    deployer: {
      default: 0, // here this will by default take the first account as deployer
      1: 0, // similarly on mainnet it will take the first account as deployer. Note though that depending on how hardhat network are configured, the account 0 on one network can be different than on another
    },
  },
};
