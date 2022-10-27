const { expect } = require("chai");
const { ethers } = require("hardhat");
// advantage of Hardhat Network's snapshot functionality.
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");

describe("Token contract", function () {

  async function deployTokenFixture() {
    // Get the ContractFactory and Signers here.
    const Token = await ethers.getContractFactory("MerkleDistributorRH");
    const [owner, addr1, addr2] = await ethers.getSigners();

    // To deploy our contract, we just have to call Token.deploy() and await
    // its deployed() method, which happens onces its transaction has been
    // mined.
    const expiryDate = Math.floor(Date.now() /1000) + 10000;

    const hardhatToken = await Token.deploy("0x0000000000000000000000000000000000000000", expiryDate);

    await hardhatToken.deployed();

    // Fixtures can return anything you consider useful for your tests
    return { Token, hardhatToken, owner, addr1, addr2 };
  }
  describe("Deployment", function () {
    it("Deployment should assign the correct contract address", async function () {
      const { hardhatToken, owner } = await loadFixture(deployTokenFixture);
      const tokenContractAddress = await hardhatToken.token(); 
      expect(tokenContractAddress).to.equal("0x0000000000000000000000000000000000000000");
    });
    it("Deployment should set the correct owner address", async function() {
      const { hardhatToken, owner } = await loadFixture(deployTokenFixture);      
      expect(await hardhatToken.owner()).to.equal(owner.address);
    });
  });


  describe("Allowlist", function() {
    it("Deployment should set an allowlist", async function () {
      const { hardhatToken, owner } = await loadFixture(deployTokenFixture);
      const merkleRoot = await hardhatToken.setMerkleRoot("0xdefa96435aec82d201dbd2e5f050fb4e1fef5edac90ce1e03953f916a5e1132d");
      const getMerkleRoot = await hardhatToken.merkleRoot();
      expect(getMerkleRoot).to.equal("0xdefa96435aec82d201dbd2e5f050fb4e1fef5edac90ce1e03953f916a5e1132d");
    });
    it("Deployment should allow only owner set an allowlist", async function () {
      const { hardhatToken, owner, addr1 } = await loadFixture(deployTokenFixture);
      await expect(hardhatToken.connect(addr1).setMerkleRoot("0xdefa96435aec82d201dbd2e5f050fb4e1fef5edac90ce1e03953f916a5e1132d"))
      .to.be.revertedWith("Ownable: caller is not the owner");
    });
    it("Deployment should allow owner to update the allowlist", async function () {
      const { hardhatToken, owner } = await loadFixture(deployTokenFixture);
      let merkleRoot = await hardhatToken.setMerkleRoot("0xdefa96435aec82d201dbd2e5f050fb4e1fef5edac90ce1e03953f916a5e1132d");
      let getMerkleRoot = await hardhatToken.merkleRoot();
      expect(getMerkleRoot).to.equal("0xdefa96435aec82d201dbd2e5f050fb4e1fef5edac90ce1e03953f916a5e1132d");
      merkleRoot = await hardhatToken.setMerkleRoot("0xdefa96435aec82d201dbd2e5f050fb4e1fef5edac90ce1e03953f916a5e0032d");
      getMerkleRoot = await hardhatToken.merkleRoot();
      expect(getMerkleRoot).to.equal("0xdefa96435aec82d201dbd2e5f050fb4e1fef5edac90ce1e03953f916a5e0032d");    
    });    
  });

});