const { ethers, upgrades, deployments, getNamedAccounts } = require("hardhat");
const { expect, assert } = require("chai");

describe("NFTMARKETPLACE", function () {
    let nftMarketPlace;
    let deployer;
    const sendValue = ethers.utils.parseEther("1");

    beforeEach(async () => {
        deployer = (await getNamedAccounts()).deployer;
        await deployments.fixture(["all"]); // Deploys all contracts in the fixture
        nftMarketPlace = await ethers.getContract("NFTMARKETPLACE", deployer);
    });

    // Tests the constructor
    describe("constructor", async () => {
        it("checks if owner is set properly", async () => {
            const response = await nftMarketPlace.getOwner();
            assert.equal(response, deployer);
        });
    });

    // Tests the createToken function
    describe("createToken", async () => {
        it("checks if members can create a token", async () => {
            await nftMarketPlace.addmembers(deployer);

            // Get the current timestamp
            const currentTime = new Date().getTime();

            // Add 1 minute (60 seconds) in milliseconds to the current time
            const oneMinuteAhead = new Date(currentTime + 60 * 1000);

            // Convert the timestamp to uint256 (in seconds)
            const uintTimestamp = Math.floor(oneMinuteAhead / 1000);

            const result = await nftMarketPlace.createToken(
                "tokenUrl", // IPFS
                1,
                "hardware",
                true,
                "whihwohhewhewiohweihoewhihweiowe",
                uintTimestamp,
                { value: sendValue }
            );

            await expect(result).to.emit(nftMarketPlace, "idMarketCreated");
        });
    });
});


/**
 * downgrading the ethers to ethers@5.7.1 and installing hardhat on dev dependencies;
 */