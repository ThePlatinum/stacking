// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ITRC20 {
    event Transfer( address indexed from, address indexed to, uint256 value);
    event Approval( address indexed owner, address indexed spender, uint256 value);
    function totalSupply() external view returns (uint256);
    function balanceOf( address account) external view returns (uint256);
    function transfer( address to, uint256 amount) external returns (bool);
    function allowance( address owner, address spender) external view returns (uint256);
    function transferFrom( address from, address to, uint256 amount ) external returns (bool);
}
 
interface ITRC165 {
  function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

interface ITRC721 is ITRC165 {
  event Transfer( address indexed from, address indexed to, uint256 indexed tokenId);
  event Approval( address indexed owner, address indexed approved, uint256 indexed tokenId);
  event ApprovalForAll( address indexed owner, address indexed operator, bool approved);

  function balanceOf( address owner) external view returns (uint256 balance);
  function ownerOf(uint256 tokenId) external view returns ( address owner);
  function safeTransferFrom( address from, address to, uint256 tokenId, bytes calldata data ) external;
  function safeTransferFrom( address from, address to, uint256 tokenId ) external;
  function transferFrom( address from, address to, uint256 tokenId ) external;
  function approve( address to, uint256 tokenId) external;
  function setApprovalForAll( address operator, bool _approved) external;
  function getApproved(uint256 tokenId) external view returns ( address operator);
  function isApprovedForAll( address owner, address operator) external view returns (bool);
}

interface TRC721TokenReceiver {
  function onTRC721Received(address _operator, address _from, uint256 _tokenId, bytes calldata _data) external returns(bytes4);
}

contract Ownable {
  address private _owner;

  constructor () {
    _owner = msg.sender;
  }

  function owner() public view returns ( address) {
    return _owner;
  }

  modifier onlyOwner() {
    require(owner() == msg.sender, "Ownable: caller is not the owner");
    _;
  }
}

contract CubieStacking is Ownable, TRC721TokenReceiver {
  
  ITRC20 public immutable TOKEN_CONTRACT;
  ITRC721 public immutable NFT_CONTRACT;

  uint256 internal dailyReward = 10000000;

  event CubieStaked( address indexed owner, uint256 tokenId, uint256 value);
  event CubieUnstaked( address indexed owner, uint256 tokenId, uint256 value);
  event RewardClaimed( address owner, uint256 reward);

  constructor( address payable _NFT_CONTRACT, address payable _TOKEN_CONTRACT) payable {
    require(msg.value > 999, "Constructor: Send a minimum of 1 trx");
    NFT_CONTRACT = ITRC721(_NFT_CONTRACT);
    TOKEN_CONTRACT = ITRC20(_TOKEN_CONTRACT);
  }

  struct Stake {
    address owner;
    uint256 tokenId;
    uint256 timestamp;
    uint256 power;
    uint256 hasPaid;
  }

  mapping(uint256 => Stake) internal vault;
  mapping(address => uint256[]) public userStacks;

  function setDailyReward(uint256 value) public onlyOwner returns(string memory) {
    dailyReward = value;
    return "Daily reward set";
  }

  function getDailyReward() public view returns(uint256) {
    return dailyReward;
  }

  function stake(uint256 tokenId, uint256 power) external payable {
    require(NFT_CONTRACT.ownerOf(tokenId) == msg.sender, "You can only stake your own token");
    require(vault[tokenId].tokenId == 0, "You can only stake once");
    require(power < 6, "Invalid mining power");
    require(msg.value < address(this).balance, "Not enough balance");

    NFT_CONTRACT.safeTransferFrom(msg.sender, address(this), tokenId);
    emit CubieStaked(msg.sender, tokenId, block.timestamp);

    vault[tokenId] = Stake({
      tokenId: tokenId,
      timestamp: block.timestamp,
      owner: msg.sender,
      power: power,
      hasPaid: 0
    });
    userStacks[msg.sender].push(tokenId);
  }

  function unstake( uint256 tokenId) internal {
    Stake memory staked = vault[tokenId];
    require(staked.owner == msg.sender, "You can only unstake your own token");
    require(NFT_CONTRACT.ownerOf(tokenId) == address(this), "This token is not staked");

    NFT_CONTRACT.safeTransferFrom( address(this), msg.sender, tokenId);
    emit CubieUnstaked(msg.sender, tokenId, block.timestamp);

    delete vault[tokenId];
    delete userStacks[msg.sender][tokenId];
  }

  function earnings(uint256 tokenId) public view returns(uint256) {
    uint256 earned = 0;
    Stake memory staked = vault[tokenId];
    require(staked.owner == msg.sender, "You can only claim from your own token");
    require(staked.timestamp + (1 minutes) < block.timestamp, "Token must be staked for atleast 24 hrs");

    earned = getDailyReward() * (staked.power/100) * ( (block.timestamp - staked.timestamp) / (1 minutes) );
    uint256 toPay = (earned - staked.hasPaid);

    if (toPay > 0) {
      return toPay;
    }
    else{
      return earned;
    }
  }

  function claim( uint256 tokenId, bool _unstake) external {
    address claimer = payable(msg.sender);
    uint256 earned = earnings(tokenId);
    Stake memory staked = vault[tokenId];

    if (earned > 0) {
      bool success = TOKEN_CONTRACT.transfer(claimer, earned);
      require(success);
      staked.hasPaid += earned;
      emit RewardClaimed(claimer, earned);
    }
    if(_unstake){
      unstake(tokenId);
    }
  }
  
  function onTRC721Received(
    address,
    address,
    uint256,
    bytes memory
  ) public virtual override returns (bytes4) {
    return this.onTRC721Received.selector;
  }
}