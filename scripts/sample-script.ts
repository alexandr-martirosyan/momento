import BN from "bn.js";
import hre, { artifacts, network, Web3 } from "hardhat";

const metamaskFirstAccount = "0xCE2496baff9b404b9C8f5445B48bA92441ed6B33";
const externalAccount = "0x5c3da587066a903d7e4f94dbc83f84df23a0a0f0";

const printBalance = async (address: string): Promise<void> => {
  const balance = await web3.eth.getBalance(address);
  console.log(Web3.utils.fromWei(Web3.utils.toBN(balance).toString()), "ETH");
};

const sendEther = async (from: string, to: string, value: BN): Promise<any> => {
  return web3.eth.sendTransaction({ from, to, value });
};

const main = async (): Promise<void> => {};

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
