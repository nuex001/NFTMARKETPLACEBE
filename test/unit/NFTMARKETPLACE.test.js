const { ethers, upgrades, deployments, getNamedAccounts } = require("hardhat");
const { expect, assert } = require("chai");
// const { Counters } = require("@openzeppelin/contracts");


describe("NFTMARKETPLACE", function () {
    let nftMarketPlace;
    let deployer;
    const sendValue = ethers.utils.parseEther("0.00025");

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
        it("checks if members can create a token", async () => { // Test logic for members creating a token
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
        it("checks if non-members cannot create a token", async () => { // Attempt to create a token as a non-member
            const [owner, addr1] = await ethers.getSigners()
            // Get the current timestamp
            const currentTime = new Date().getTime();

            // Add 1 minute (60 seconds) in milliseconds to the current time
            const oneMinuteAhead = new Date(currentTime + 60 * 1000);

            // Convert the timestamp to uint256 (in seconds)
            const uintTimestamp = Math.floor(oneMinuteAhead / 1000);
            try {
                const result = await nftMarketPlace.connect(addr1).createToken(
                    "tokenUrl", // IPFS
                    1,
                    "hardware",
                    true,
                    "whihwohhewhewiohweihoewhihweiowe",
                    uintTimestamp,
                    { value: sendValue }
                );
                assert.fail('Expected revert not received');
            } catch (error) {
                await expect(error.message).to.include('NFTMARKETPLACE__NotMEMBER');
            }
        });
    });

    // Tests the ReSellToken function
    describe("Buy Or ReSellToken", async () => {
        let tokenId;
        beforeEach(async () => {
            const currentTime = new Date().getTime();

            const oneMinuteAhead = new Date(currentTime + 60 * 1000);

            const uintTimestamp = Math.floor(oneMinuteAhead / 1000);

            const transaction = await nftMarketPlace.createToken(
                "tokenUrl", // IPFS
                1,
                "hardware",
                false,
                "whihwohhewhewiohweihoewhihweiowe",
                uintTimestamp,
                { value: sendValue }
            );
            const receipt = await transaction.wait();
            const events = receipt.events;
            const tokenidEvents = events.find((event) => event.event === 'idMarketCreated');
            tokenId = tokenidEvents.args.tokenId;
        })
        it("checks if members can buy a token", async () => { // Test logic for members creating a token
            const result = await nftMarketPlace.createMarketSale(tokenId,
                { value: ethers.utils.parseEther("2") }
            )
            await expect(result).to.emit(nftMarketPlace, "CreateMarketSale");
        });

        it("checks if members can resale a token", async () => { // which we have to buy first
            await nftMarketPlace.createMarketSale(tokenId,
                { value: ethers.utils.parseEther("1") }
            )
            const result = await nftMarketPlace.reSellToken(tokenId, 2,
                { value: sendValue }
            )
            await expect(result).to.emit(nftMarketPlace, "Resell");
        });
    });

    // Make Bidding
    describe("bid", async () => {
        let tokenId;
        beforeEach(async () => {
            const currentTime = new Date().getTime();

            const oneMinuteAhead = new Date(currentTime + 60 * 1000);

            const uintTimestamp = Math.floor(oneMinuteAhead / 1000);

            const transaction = await nftMarketPlace.createToken(
                "tokenUrl", // IPFS
                1,
                "hardware",
                true,
                "whihwohhewhewiohweihoewhihweiowe",
                uintTimestamp,
                { value: sendValue }
            );
            const receipt = await transaction.wait();
            const events = receipt.events;
            const tokenidEvents = events.find((event) => event.event === 'idMarketCreated');
            tokenId = tokenidEvents.args.tokenId;
            await nftMarketPlace.startAuction(tokenId);
        })
        it("Let's make Bid", async () => {
            const result = await nftMarketPlace.bid(tokenId,
                { value: ethers.utils.parseEther("2") }
            )
            await expect(result).to.emit(nftMarketPlace, "Bid");
        })
        it("Let's withdraw Bid", async () => {
            await nftMarketPlace.bid(tokenId,
                { value: ethers.utils.parseEther("2") }
            )
            const result = await nftMarketPlace.withdrawBids(tokenId)
            await expect(result).to.emit(nftMarketPlace, "WithdrawBids");
        })
    });
    // End Bid
    describe("End bid", async () => {
        let tokenId;
        beforeEach(async () => {
            const currentTime = new Date().getTime();

            const oneMinuteAhead = new Date(currentTime - 90 * 1000);

            const uintTimestamp = Math.floor(oneMinuteAhead / 1000);

            const transaction = await nftMarketPlace.createToken(
                "tokenUrl", // IPFS
                1,
                "hardware",
                true,
                "whihwohhewhewiohweihoewhihweiowe",
                uintTimestamp,
                { value: sendValue }
            );
            const receipt = await transaction.wait();
            const events = receipt.events;
            const tokenidEvents = events.find((event) => event.event === 'idMarketCreated');
            tokenId = tokenidEvents.args.tokenId;
            await nftMarketPlace.startAuction(tokenId);
        })
        it("Let's end Bid", async () => {
            const result = await nftMarketPlace.end(tokenId)
            await expect(result).to.emit(nftMarketPlace, "End");
        })
    });

    // GETTERS
    describe("Getters", async () => {
        let tokenId;
        let address2;
        beforeEach(async () => {
            const [owner, addr1] = await ethers.getSigners();
            address2 = addr1.address;
            const currentTime = new Date().getTime();

            const oneMinuteAhead = new Date(currentTime + 60 * 1000);

            const uintTimestamp = Math.floor(oneMinuteAhead / 1000);
            await nftMarketPlace.createToken(
                "tokenUrl", // IPFS
                1,
                "hardware",
                false,
                "whihwohhewhewiohweihoewhihweiowe",
                uintTimestamp,
                { value: sendValue }
            );
            // add memmber
            await nftMarketPlace.addmember(address2);
            // run transaction with the second address with cat as software
            const transaction = await nftMarketPlace.connect(addr1).createToken(
                "tokenUrl", // IPFS
                1,
                "software",
                false,
                "whihwohhewhewiohweihoewhihweiowe",
                uintTimestamp,
                { value: sendValue }
            );
            const receipt = await transaction.wait();
            const events = receipt.events;
            const tokenidEvents = events.find((event) => event.event === 'idMarketCreated');
            tokenId = tokenidEvents.args.tokenId;
        })
        it("Get marketItems", async () => {
            const res = await nftMarketPlace.fetchMarketItem();
            assert.equal(res.length, 2);
        })
        it("Get myNfts", async () => {
            // Bu Nfts
            await nftMarketPlace.createMarketSale(tokenId,
                { value: ethers.utils.parseEther("2") }
            )
            // Now check bought Nfts
            const res = await nftMarketPlace.fetchMyNFTs();
            assert.equal(res.length, 1);
        })
        it("Filter marketItems by Category", async () => {
            const res = await nftMarketPlace.filterNftCat("software");
            assert.equal(res.length, 1);
        })
        it("Filter marketItems by Adrress", async () => {
            const res = await nftMarketPlace.filterNftByAdress(address2);
            assert.equal(res.length, 1);
        })
        it("Get marketItems details", async () => {
            const res = await nftMarketPlace.fetchNFTsDetails(tokenId);
            assert.equal(res.length, 2);
        })
        it("Get fetchTokenUrl", async () => {
            const res = await nftMarketPlace.fetchTokenUrl(tokenId);
            assert.equal(res, "tokenUrl");
        })
    })
});


/**
 * downgrading the ethers to ethers@5.7.1 and installing hardhat on dev dependencies;
 */