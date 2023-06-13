// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
// Uncomment this line to use console.log
import "hardhat/console.sol";
error NFTMARKETPLACE__lowPrice();
error NFTMARKETPLACE__lowListingPrice();

contract NFTMARKETPLACE is ERC721URIStorage {
    // EVENTS
    event idMarketCreated(
        uint256 indexed tokenId,
        address seller,
        address owner,
        uint256 price,
        bool bidding,
        bool sold
    );
    event Bid(address indexed sender, uint256 amount);
    event WithdrawBids(address indexed bidder, uint256 amount);
    event End(address indexed highestBidder, uint256 highestBid);

    struct MarketItem {
        uint256 tokenId;
        address payable seller;
        address payable owner;
        uint256 price;
        string itemType;
        bool bidding;
        string details;
        bool sold;
    }
    // state variable
    address payable private immutable i_owner;
    mapping(uint256 => uint256) public s_endAt;
    mapping(uint256 => bool) public s_ended;
    mapping(uint256 => bool) public s_started;
    mapping(uint256 => address) public s_highestBidder;
    mapping(uint256 => uint256) public s_highestBid;
    mapping(uint256 => mapping(address => uint)) public s_bids;
    // normal
    using Counters for Counters.Counter;
    Counters.Counter private s_tokenIds;
    Counters.Counter private s_tokensold;
    mapping(uint256 => MarketItem) private s_IdMarketItem;
    mapping(address => bool) public s_members;
    uint256 s_listingPrice = 0.00025 ether;
    // MODIFIERS
    modifier onlyOwner() {
        require(msg.sender == i_owner, "Autorization denied");
        _;
    }
    modifier onlyMember() {
        require(s_members[msg.sender], "Strictly for members Only");
        _;
    }

    //CONSTRUCTOR
    constructor() ERC721("STREET NFT TOKEN", "STRTNFT") {
        i_owner = payable(msg.sender);
    }

    // CREATE TOKEN
    function createToken(
        string memory tokenUrl, //ipfs
        uint256 price,
        string memory itemType,
        bool bidding,
        string memory _details,
        uint256 timestamp
     ) public payable onlyMember returns (uint256) {
        s_tokenIds.increment();
        uint256 newTokenId = s_tokenIds.current();
        _mint(msg.sender, newTokenId);
        _setTokenURI(newTokenId, tokenUrl);
        createMarketItem(
            newTokenId,
            price,
            itemType,
            bidding,
            _details,
            timestamp
        );
        return newTokenId;
    }

    // CREATE MARKET ITEM
    function createMarketItem(
        uint256 tokenId,
        uint256 price,
        string memory itemType,
        bool bidding,
        string memory _details,
        uint256 timestamp
     ) private {
        if (price < 0) {
            revert NFTMARKETPLACE__lowPrice();
        }
        if (msg.value == s_listingPrice) {
            revert NFTMARKETPLACE__lowListingPrice();
        }
        // Checking for devices
        s_IdMarketItem[tokenId] = MarketItem(
            tokenId,
            payable(msg.sender),
            payable(address(this)),
            price,
            itemType,
            bidding,
            _details,
            false
        );

        // working for bidding
        if (timestamp > 0) {
            s_endAt[tokenId] = timestamp; //mapping the timestamp to the tokenId
        }

        _transfer(msg.sender, address(this), tokenId);
        emit idMarketCreated(
            tokenId,
            msg.sender,
            address(this),
            price,
            bidding,
            false
        );
    }

    // RESALE TOKEN
    function reSellToken(
        uint256 tokenId,
        uint256 price
     ) public payable onlyMember {
        require(
            s_IdMarketItem[tokenId].price == 0,
            "Sorry the token doesn't exist"
        );
        MarketItem storage newMarketItem = s_IdMarketItem[tokenId];
        require(newMarketItem.seller == msg.sender, "Not Authorized");
        require(msg.value == s_listingPrice, " Eth below Listing Price");
        newMarketItem.sold = false;
        newMarketItem.price = price;
        newMarketItem.seller = payable(msg.sender);
        newMarketItem.owner = payable(address(this));
        s_tokensold.decrement();
        _transfer(msg.sender, address(this), tokenId);
    }

    //
    function transferNftOwnership(uint256 tokenId) internal {
        MarketItem storage newMarketItem = s_IdMarketItem[tokenId];
        newMarketItem.seller = payable(msg.sender);
        newMarketItem.owner = payable(address(this));
        newMarketItem.sold = true;
        s_tokensold.increment();
    }

    function createMarketSale(uint256 tokenId) public payable {
        require(
            s_IdMarketItem[tokenId].price == 0,
            "Sorry the token doesn't exist"
        );
        MarketItem storage newMarketItem = s_IdMarketItem[tokenId];
        uint256 price = newMarketItem.price;
        if (msg.value == price) {
            revert NFTMARKETPLACE__lowPrice();
        }
        transferNftOwnership(tokenId);
        _transfer(address(this), msg.sender, tokenId);
        payable(i_owner).transfer(s_listingPrice);
        payable(newMarketItem.seller).transfer(msg.value);
    }

    function bid(uint256 tokenId) external payable {
        require(block.timestamp < s_endAt[tokenId], "ended");
        require(msg.value > s_highestBid[tokenId], "Value < highest Bid");
        // keep track of bids
        if (s_highestBidder[tokenId] != address(0)) {
            s_bids[tokenId][s_highestBidder[tokenId]] += s_highestBid[tokenId];
        }
        s_highestBid[tokenId] = msg.value;
        s_highestBidder[tokenId] = msg.sender;
        emit Bid(msg.sender, msg.value);
    }

    function withdrawBids(uint256 tokenId) external {
        uint bal = s_bids[tokenId][s_highestBidder[tokenId]];
        s_bids[tokenId][s_highestBidder[tokenId]] = 0; //stoping reentrancy attack
        payable(msg.sender).transfer(bal);
        emit WithdrawBids(msg.sender, bal);
    }

    //End Bids
    function end(uint256 tokenId) external {
        require(s_started[tokenId], "Not started");
        require(!s_ended[tokenId], "ended");
        require(block.timestamp >= s_endAt[tokenId], "Not ended");
        s_ended[tokenId] = true;
        if (s_highestBidder[tokenId] == address(0)) {
            _transfer(address(this), s_highestBidder[tokenId], tokenId);
            payable(s_IdMarketItem[tokenId].seller).transfer(
                s_highestBid[tokenId]
            );
            transferNftOwnership(tokenId);
        } else {
            _transfer(address(this), s_IdMarketItem[tokenId].seller, tokenId);
        }
        emit End(s_highestBidder[tokenId], s_highestBid[tokenId]);
    }

    // add members
    function addmembers(address _member) external onlyOwner {
        s_members[_member] = true;
    }

    // GETTERS
    function getListing() public view returns (uint256) {
        return s_listingPrice;
    }

    function fetchMarketItem() public view returns (MarketItem[] memory) {
        uint256 itemCount = s_tokenIds.current();
        uint256 unSoldItemCount = s_tokenIds.current() - s_tokensold.current();
        uint256 currentIdx = 0;
        MarketItem[] memory items = new MarketItem[](unSoldItemCount); //initializing an array of struct
        for (uint256 i = 0; i < itemCount; i++) {
            if (s_IdMarketItem[i + 1].owner == address(this)) {
                uint256 currentId = i + 1;
                MarketItem storage currentItem = s_IdMarketItem[currentId];
                items[currentIdx] = currentItem;
                currentIdx += 1;
            }
        }
        return items;
    }

    function fetchMyNFTs() public view returns (MarketItem[] memory) {
        uint256 totalCount = s_tokenIds.current();
        uint256 itemCount = 0;
        uint256 currentIdx = 0;

        for (uint256 i = 0; i < totalCount; i++) {
            //getting the count of nft owned by the user
            if (s_IdMarketItem[i + 1].owner == msg.sender) {
                itemCount += 1;
            }
        }

        MarketItem[] memory items = new MarketItem[](itemCount); //initializing an array of struct
        for (uint256 i = 0; i < totalCount; i++) {
            if (s_IdMarketItem[i + 1].owner == msg.sender) {
                uint256 currentId = i + 1;
                MarketItem storage currentItem = s_IdMarketItem[currentId];
                items[currentIdx] = currentItem;
                currentIdx += 1;
            }
        }
        return items;
    }

    function filterNftByAdress(
        address _owner
     ) public view returns (MarketItem[] memory) {
        uint256 totalCount = s_tokenIds.current();
        uint256 itemCount = 0;
        uint256 currentIdx = 0;

        for (uint256 i = 0; i < totalCount; i++) {
            //getting the count of nft owned by the address
            if (s_IdMarketItem[i + 1].seller == payable(_owner)) {
                itemCount += 1;
            }
        }

        MarketItem[] memory items = new MarketItem[](itemCount); //initializing an array of struct
        for (uint256 i = 0; i < totalCount; i++) {
            if (s_IdMarketItem[i + 1].seller == payable(_owner)) {
                uint256 currentId = i + 1;
                MarketItem storage currentItem = s_IdMarketItem[currentId];
                items[currentIdx] = currentItem;
                currentIdx += 1;
            }
        }
        return items;
    }

    function filterNftCat(
        string memory cat
     ) public view returns (MarketItem[] memory) {
        uint256 totalCount = s_tokenIds.current();
        uint256 itemCount = 0;
        uint256 currentIdx = 0;

        for (uint256 i = 0; i < totalCount; i++) {
            //getting the count of nft cat
            if (
                keccak256(bytes(s_IdMarketItem[i + 1].itemType)) ==
                keccak256(bytes(cat))
            ) {
                itemCount += 1;
            }
        }

        MarketItem[] memory items = new MarketItem[](itemCount); //initializing an array of struct
        for (uint256 i = 0; i < totalCount; i++) {
            if (
                keccak256(bytes(s_IdMarketItem[i + 1].itemType)) ==
                keccak256(bytes(cat))
            ) {
                uint256 currentId = i + 1;
                MarketItem storage currentItem = s_IdMarketItem[currentId];
                items[currentIdx] = currentItem;
                currentIdx += 1;
            }
        }
        return items;
    }

    function fetchNFTsDetails(
        uint256 tokenId
     ) public view returns (MarketItem memory, string memory /**ipfs url */) {
        return (s_IdMarketItem[tokenId], tokenURI(tokenId));
    }
}

/**
 * NOTE : i can't call a public funtion within a function , i think it's only private and internal,and vise versa with payable
 */
