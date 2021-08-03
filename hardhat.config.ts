import "@nomiclabs/hardhat-truffle5";
import "@typechain/hardhat";
import { HardhatNetworkForkingUserConfig, HardhatUserConfig } from "hardhat/types";

const isMainnetFork = false;
const isRinkebyFork = true;

let forking: HardhatNetworkForkingUserConfig | undefined;
let chainId: 1 | 4 | 31337 | 5 = 31337;

if (isMainnetFork || isRinkebyFork) {
  chainId = isMainnetFork ? 1 : 4;
  forking = { url: `http://127.0.0.1:955${isMainnetFork ? 5 : 8}` };
}

chainId = 5;

const config: HardhatUserConfig = {
  defaultNetwork: "hardhat",
  solidity: {
    compilers: [
      {
        version: "0.8.4",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
      {
        version: "0.6.12",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
  },
  typechain: {
    target: "truffle-v5",
  },
  networks: {
    hardhat: {
      chainId,
      forking,
      accounts: {
        mnemonic:
          "myth like bonus scare over problem client lizard pioneer submit female collect",
        count: 10,
        accountsBalance: "10000000000000000000000",
      },
    },
    node_network: {
      url: "http://127.0.0.1:8545",
    },
  },
};

export default config;
