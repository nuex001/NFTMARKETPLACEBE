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

enum Type { Software, Hardware}

// EVENTS
event idMarketCreated (
    uint256 indexed tokenId,
    address seller,
    address owner,
    uint256 price,
    bool sold
);

   struct MarketItem {
    uint256 tokenId;
    address payable seller;
    address payable owner;
    uint256 price;
    Type itemType;
    bool bidding;
    bool sold;
   }

    // state variable
    address payable immutable private i_owner;
    // Bidding
   mapping(uint256 => uint32)  public endAt;
   mapping(uint256 => bool) public s_started;
   mapping(uint256 => bool) public s_highestBidder;
   mapping(uint256 => bool) public s_highestBid;
   mapping(uint256 => mapping(address=>uint)) public s_bids;
  // normal
    using Counters for Counters.Counter;
    Counters.Counter private s_tokenIds;
    Counters.Counter private s_tokensold;
   mapping(uint256 => MarketItem)  private s_IdMarketItem;
   mapping(address => MarketItem[])  private s_MapIdMarketItems;
   mapping(address => bool) public members;
   uint256 s_listingPrice = 0.00025 ether;

// MODIFIERS
modifier onlyOwner {
    require(
        msg.sender == i_owner,
        "Autorization denied"
    );
    _;
}
modifier onlyMember{
    require(
        members[msg.sender],
        "Strictly for Members Only"
    );
    _;
}

  //CONSTRUCTOR
  constructor() ERC721("STREET NFT TOKEN" , "STRTNFT"){
    i_owner =payable(msg.sender);
  }

    // CREATE TOKEN
    function createToken(
        string memory tokenUrl, //ipfs
        uint256 price,
        string memory itemType,
        bool bidding,
       uint256 timestamp
    ) public payable returns(uint256){
        s_tokenIds.increment();
        uint256 newTokenId = s_tokenIds.current();
        _mint(msg.sender,newTokenId);
        _setTokenURI(newTokenId,tokenUrl);
        createMarketItem(newTokenId,price,itemType,bidding,timestamp);
        return newTokenId;
    }

    // CREATE MARKET ITEM
    function createMarketItem(uint256 tokenId, uint256 price , string memory itemType , bool bidding , uint256 timestamp) private{
      if (price < 0) {
        revert NFTMARKETPLACE__lowPrice();
      }
      if (msg.value == s_listingPrice) {
        revert NFTMARKETPLACE__lowListingPrice();
      }
      // Checking for devices
  if (keccak256(bytes(itemType)) == keccak256(bytes("Software"))) {
    s_IdMarketItem[tokenId] = MarketItem(
      tokenId,
      payable(msg.sender),
      payable(address(this)),
      price,
      Type.Software,
      bidding,
      false
      ) ;
              
   // mapping for the address search
   s_MapIdMarketItems[msg.sender].push(MarketItem(
      tokenId,
      payable(msg.sender),
      payable(address(this)),
      price,
      Type.Software,
      bidding,
      false
      ));
  } else if (keccak256(bytes(itemType)) == keccak256(bytes("Hardware"))) {
    s_IdMarketItem[tokenId] = MarketItem(
      tokenId,
      payable(msg.sender),
      payable(address(this)),
      price,
      Type.Hardware,
      bidding,
      false
      ) ;
          
   // mapping for the address search
   s_MapIdMarketItems[msg.sender].push(MarketItem(
      tokenId,
      payable(msg.sender),
      payable(address(this)),
      price,
      Type.Hardware,
      bidding,
      false
      ));
  }  

  // working for bidding
 if (timestamp > 0) {
  
 }

  _transfer(msg.sender,address(this),tokenId);
     emit  idMarketCreated (
     tokenId,
     msg.sender,
     address(this),
     price,
     false
     );
    }

   // RESALE TOKEN
    function reSellToken(uint256 tokenId, uint256 price) public payable {
     require(s_IdMarketItem[tokenId].price == 0, "Sorry the token doesn't exist");
      MarketItem storage newMarketItem = s_IdMarketItem[tokenId];
     require(newMarketItem.owner == msg.sender , "Not Authorized");
     require(msg.value == s_listingPrice , "Not Authorized");
      newMarketItem.sold = false;
      newMarketItem.price = price;
      newMarketItem.seller = payable(msg.sender);
      newMarketItem.owner = payable(address(this));
      s_tokensold.decrement();
      _transfer(msg.sender,address(this),tokenId);
    }

    function createMarketSale (uint256 tokenId) public payable {
      require(s_IdMarketItem[tokenId].price == 0, "Sorry the token doesn't exist");
      MarketItem storage newMarketItem = s_IdMarketItem[tokenId];
      uint256 price = newMarketItem.price;
      if (msg.value == price) {
      revert NFTMARKETPLACE__lowPrice();
      }
      newMarketItem.seller = payable(msg.sender);
      newMarketItem.owner = payable(msg.sender);
      newMarketItem.sold = true;
      s_tokensold.increment();
      _transfer(address(this),msg.sender,tokenId);
      payable(i_owner).transfer(s_listingPrice);
      payable(newMarketItem.seller).transfer(msg.value);

    }
 


    //    GETTERS
    function getListing() public view returns(uint256){
    return s_listingPrice;
    }
}

/**
 * NOTE : i can't call a public funtion within a function , i think it's only private and internal,and vise versa with payable
 */