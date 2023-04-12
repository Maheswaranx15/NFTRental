// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");
const fs = require("fs");
const { ethers } = require("hardhat");

async function main() {
  let NFT721Name = 'ERC721NFT'
  let NFT1155Name = 'ERC1155NFT'
  let NFT721SYMBOL = 'NFT721'
  let NFT1155SYMBOL = 'NFT1155'
  let TokenURI = 'https://gateway.pinata.cloud/ipfs'
  let buyerFee = 25
  let sellerFee = 30

  const Proxy = await hre.ethers.getContractFactory("TransferProxy");
  const proxy = await Proxy.deploy();
  await proxy.deployed();
  console.log(`proxy contract address`,proxy.address);

  const Escrow = await hre.ethers.getContractFactory("Escrow");
  const escrow = await Escrow.deploy();
  await escrow.deployed();
  console.log(`Escrow contract address`,escrow.address);

  const ERC721_NFT = await hre.ethers.getContractFactory("ERC721_NFT");
  const erc721 = await ERC721_NFT.deploy(NFT721Name,NFT721SYMBOL,TokenURI,proxy.address,escrow.address);
  await erc721.deployed();
  console.log(`ERC721 contract address`,erc721.address);

  const ERC1155_NFT = await hre.ethers.getContractFactory("ERC1155_NFT");
  const erc1155 = await ERC1155_NFT.deploy(NFT1155Name,NFT1155SYMBOL,TokenURI,proxy.address,escrow.address);
  await erc1155.deployed();
  console.log(`ERC1155 contract address`,erc1155.address);

  const Trade = await hre.ethers.getContractFactory("Trade");
  const trade = await Trade.deploy(buyerFee,sellerFee,proxy.address);
  await trade.deployed();
  console.log(`Trade contract address`,trade.address);

  const proxydata = {
    address: proxy.address,
    abi: JSON.parse(proxy.interface.format('json'))
  }
  fs.writeFileSync('./abis/proxy.json', JSON.stringify(proxydata))

  const Escrowdata = {
    address: escrow.address,
    abi: JSON.parse(escrow.interface.format('json'))
  }
  fs.writeFileSync('./abis/Escrow.json', JSON.stringify(Escrowdata))

  const erc721data = {
    address: erc721.address,
    abi: JSON.parse(erc721.interface.format('json'))
  }
  fs.writeFileSync('./abis/ERC721.json', JSON.stringify(erc721data))


  const erc1155data = {
    address: erc1155.address,
    abi: JSON.parse(erc1155.interface.format('json'))
  }
  fs.writeFileSync('./abis/ERC1155.json', JSON.stringify(erc1155data))


  const tradedata = {
    address: trade.address,
    abi: JSON.parse(trade.interface.format('json'))
  }
  fs.writeFileSync('./abis/Trade.json', JSON.stringify(tradedata))


  await hre.run("verify:verify", {
    address: proxy.address,
  });

  await hre.run("verify:verify", {
    address: escrow.address,
    constructorArguments: [buyerFee,proxy.address],
  });

  await hre.run("verify:verify", {
    address: erc721.address,
    constructorArguments: [NFT721Name,NFT721SYMBOL,TokenURI,proxy.address,escrow.address],
  });

  await hre.run("verify:verify", {
    address: erc1155.address,
    constructorArguments: [NFT1155Name,NFT1155SYMBOL,TokenURI,proxy.address,escrow.address],
  });
  



}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
