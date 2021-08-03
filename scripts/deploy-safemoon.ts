import { SafeMoonContract, SafeMoonInstance } from "../typechain";

const main = async (): Promise<SafeMoonInstance> => {
  const accounts = await web3.eth.getAccounts();
  const accountsObj = accounts.reduce(
    (acc, account, index) => ({ ...acc, [`Account-${index}`]: account }),
    {}
  );
  console.table(accountsObj);
  const SafeMoon: SafeMoonContract = artifacts.require("SafeMoon");
  return SafeMoon.new({ from: accounts[0] });
};

main().then((safeMoon) => {
  console.table({ SAFEMOON: safeMoon.address });
});
