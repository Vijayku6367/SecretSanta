import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-ethers";
import "@fhevm/hardhat-plugin";

const config: HardhatUserConfig = {
  solidity: "0.8.24",
  networks: {
    hardhat: { chainId: 31337 }
  }
};

export default config;
import "@nomicfoundation/hardhat-chai-matchers";
