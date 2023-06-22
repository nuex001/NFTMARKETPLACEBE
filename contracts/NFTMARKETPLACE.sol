// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
// Uncomment this line to use console.log
import "hardhat/console.sol";
error NFTMARKETPLACE__lowPrice();
error NFTMARKETPLACE__lowListingPrice();
error NFTMARKETPLACE__NotMEMBER();
error NFTMARKETPLACE__OnlyOwner();
error NFTMARKETPLACE__UnAuthorized();
error NFTMARKETPLACE__OnlyForBidding();
error NFTMARKETPLACE__NotStarted();
error NFTMARKETPLACE__TokenNotExist();
error NFTMARKETPLACE__Ended();

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
    event CreateMarketSale(
        address indexed buyer,
        uint256 tokenId,
        uint256 price
    );
    event Resell(address indexed seller, uint256 price);
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
        uint timestamp;
        bool started;
    }
    // state variable
    address payable private immutable i_owner;
    mapping(uint256 => uint256) private s_endAt;
    mapping(uint256 => bool) private s_ended;
    mapping(uint256 => address) private s_highestBidder;
    mapping(uint256 => mapping(address => uint)) public s_bids;
    // normal
    using Counters for Counters.Counter;
    Counters.Counter private s_tokenIds;
    Counters.Counter private s_tokensold;
    mapping(uint256 => MarketItem) private s_IdMarketItem;
    mapping(address => bool) private s_members;
    uint256 constant s_listingPrice = 0.00025 ether;
    // MODIFIERS
    modifier onlyOwner() {
        if (msg.sender != i_owner) {
            revert NFTMARKETPLACE__OnlyOwner();
        }
        _;
    }
    modifier onlyMember() {
        if (!s_members[msg.sender] && payable(msg.sender) != i_owner) {
            revert NFTMARKETPLACE__NotMEMBER();
        }
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
    ) internal {
        if (price <= 0) {
            revert NFTMARKETPLACE__lowPrice();
        }
        if (msg.value != s_listingPrice) {
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
            false,
            timestamp,
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
        MarketItem storage newMarketItem = s_IdMarketItem[tokenId];
        if (newMarketItem.seller == address(0)) {
            revert NFTMARKETPLACE__TokenNotExist();
        }
        if (newMarketItem.owner != payable(msg.sender)) {
            revert NFTMARKETPLACE__UnAuthorized();
        }
        if (msg.value != s_listingPrice) {
            revert NFTMARKETPLACE__lowListingPrice();
        }
        newMarketItem.sold = false;
        newMarketItem.price = price;
        newMarketItem.seller = payable(msg.sender);
        newMarketItem.owner = payable(address(this));
        s_tokensold.decrement();
        // Transfer the token ownership back to the marketplace
        _transfer(msg.sender, address(this), tokenId);
        emit Resell(msg.sender, price);
    }

    //
    function transferNftOwnership(uint256 tokenId) internal {
        MarketItem storage newMarketItem = s_IdMarketItem[tokenId];
        newMarketItem.seller = payable(msg.sender);
        newMarketItem.owner = payable(msg.sender);
        newMarketItem.sold = true;
        s_tokensold.increment();
    }

    function createMarketSale(uint256 tokenId) external payable {
        MarketItem storage newMarketItem = s_IdMarketItem[tokenId];
        uint256 price = newMarketItem.price;
        if (newMarketItem.seller == address(0)) {
            revert NFTMARKETPLACE__TokenNotExist();
        }
        if (msg.value < (price * 1e18)) {
            revert NFTMARKETPLACE__lowPrice();
        }
        if (newMarketItem.bidding) {
            revert NFTMARKETPLACE__OnlyForBidding();
        }
        transferNftOwnership(tokenId);
        _transfer(address(this), msg.sender, tokenId);
        payable(i_owner).transfer(s_listingPrice);
        payable(newMarketItem.seller).transfer(msg.value);
        emit CreateMarketSale(msg.sender, tokenId, msg.value);
    }

    function startAuction(uint256 tokenId) external {
        MarketItem storage newMarketItem = s_IdMarketItem[tokenId];
        if (newMarketItem.seller != payable(msg.sender)) {
            revert NFTMARKETPLACE__UnAuthorized();
        }
        if (!newMarketItem.bidding) {
            revert NFTMARKETPLACE__OnlyForBidding();
        }
        newMarketItem.started = true;
    }

    function bid(uint256 tokenId) external payable {
        MarketItem storage newMarketItem = s_IdMarketItem[tokenId];
        if (block.timestamp > s_endAt[tokenId]) {
            revert NFTMARKETPLACE__Ended();
        }
        if (!newMarketItem.started) {
            revert NFTMARKETPLACE__NotStarted();
        }

        if (msg.value < (newMarketItem.price * 1e18)) {
            revert NFTMARKETPLACE__lowPrice();
        }
        // keep track of bids
        if (s_highestBidder[tokenId] != address(0)) {
            s_bids[tokenId][msg.sender] += newMarketItem.price;
        }
        newMarketItem.price = msg.value / 1e18;
        s_highestBidder[tokenId] = msg.sender;
        emit Bid(msg.sender, msg.value);
    }

    function withdrawBids(uint256 tokenId) external {
        uint256 bal;
        if (s_highestBidder[tokenId] == msg.sender) {
            s_highestBidder[tokenId] = address(0);
            bal = s_IdMarketItem[tokenId].price * 1e18;
        } else {
            bal = s_bids[tokenId][msg.sender] * 1e18;
            s_bids[tokenId][msg.sender] = 0; //stoping reentrancy attack
        }
        payable(msg.sender).transfer(bal);
        emit WithdrawBids(msg.sender, bal);
    }

    //End Bids
    function end(uint256 tokenId) external {
        MarketItem storage newMarketItem = s_IdMarketItem[tokenId];
        if (s_ended[tokenId]) {
            revert NFTMARKETPLACE__Ended();
        }
        require(block.timestamp >= s_endAt[tokenId], "Not ended");
        s_ended[tokenId] = true;
        address highestBidder = s_highestBidder[tokenId];
        if (highestBidder != address(0)) {
            _transfer(address(this), newMarketItem.seller, tokenId);
            payable(newMarketItem.seller).transfer(newMarketItem.price * 1e18);
            transferNftOwnership(tokenId);
            s_highestBidder[tokenId] = address(0);
        } else {
            _transfer(address(this), newMarketItem.seller, tokenId);
        }
        emit End(highestBidder, newMarketItem.price);
    }

    // add members
    function addmember(address _member) external onlyOwner {
        s_members[_member] = true;
    }

    function fetchMarketItem() external view returns (MarketItem[] memory) {
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

    function fetchMyNFTs() external view returns (MarketItem[] memory) {
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
    ) external view returns (MarketItem[] memory) {
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
    ) external view returns (MarketItem[] memory) {
        uint256 totalCount = s_tokenIds.current();
        uint256 itemCount = 0;
        uint256 currentIdx = 0;

        for (uint256 i = 0; i < totalCount; i++) {
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
    ) external view returns (MarketItem memory, string memory /**ipfs url */) {
        return (s_IdMarketItem[tokenId], tokenURI(tokenId));
    }

    function fetchTokenUrl(
        uint256 tokenId
    ) external view returns (string memory /**ipfs url */) {
        return tokenURI(tokenId);
    }

    // GETTERS
    function getListing() external pure returns (uint256) {
        return s_listingPrice / 1e18;
    }

    function getOwner() external view returns (address) {
        return i_owner;
    }
}
