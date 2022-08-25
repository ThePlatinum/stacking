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

interface IERC721Receiver {
  function onERC721Received(address _operator, address _from, uint256 _tokenId, bytes calldata _data) external returns(bytes4);
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
    require(owner() == msg.sender, "Ownable: Caller not Owner");
    _;
  }
}

contract Enumerable {

    uint256[] private _allTokens;
    mapping(uint256 => uint256) private _allTokensIndex;

    function totalSupply() public view returns (uint256) {
        return _allTokens.length;
    }

    function totalSupplyId() public view returns (uint256 [] memory) {
        return _allTokens;
    }

    function _addToken(uint256 tokenId) public {
        _allTokensIndex[tokenId] = _allTokens.length;
        _allTokens.push(tokenId);
    }

    function _removeToken(uint256 tokenId) public {
        uint256 lastTokenIndex = _allTokens.length - 1;
        uint256 tokenIndex = _allTokensIndex[tokenId];
        uint256 lastTokenId = _allTokens[lastTokenIndex];
        _allTokens[tokenIndex] = lastTokenId;
        _allTokensIndex[lastTokenId] = tokenIndex;
        _allTokens.pop();
        _allTokensIndex[tokenId] = 0;
    }
}

contract CubieStacking is Ownable, TRC721TokenReceiver, IERC721Receiver, Enumerable {

  ITRC20 public immutable TOKEN_CONTRACT;
  ITRC721 public immutable NFT_CONTRACT;

  uint256 internal dailyReward = 10 * 1e16;
  uint256 public stakeOn = 1;
  uint256 internal stake_stoped_at = 0;

  event CubieStaked  ( address indexed owner, uint256 tokenId, uint256 value);
  event CubieUnstaked( address indexed owner, uint256 tokenId, uint256 value);
  event RewardClaimed( address owner, uint256 reward);

  constructor( address payable _NFT_CONTRACT, address payable _TOKEN_CONTRACT) payable {
    NFT_CONTRACT = ITRC721(_NFT_CONTRACT);
    TOKEN_CONTRACT = ITRC20(_TOKEN_CONTRACT);
  }

  struct Stake {
    address owner;
    uint256 tokenId;
    uint256 timestamp;
    uint256 power;
  }

  mapping(uint256 => Stake) public vault;
  mapping(address => uint256[]) private userStacks;
  mapping(uint256 => uint256) public hasPaid;

  function setDailyReward(uint256 value) public onlyOwner {
    dailyReward = value * 1e16;
  }

  function getDailyReward() public view returns(uint256) {
    return dailyReward;
  }

  function _tokensOfOwner() public view returns (uint256[] memory){
    return _tokensOfOwner(msg.sender);
  }

  function _tokensOfOwner(address owner) public view returns (uint256[] memory) {
    return userStacks[owner];
  }

  function stake(uint256 tokenId, uint256 power) external payable {
    require(NFT_CONTRACT.ownerOf(tokenId) == msg.sender, "Not yours");
    require(vault[tokenId].tokenId == 0, "Only stake once");
    require(power < 6, "Invalid");
    require(stakeOn == 1, "Paused or Ended");

    NFT_CONTRACT.safeTransferFrom(msg.sender, address(this), tokenId);
    emit CubieStaked(msg.sender, tokenId, block.timestamp);

    vault[tokenId] = Stake({
      tokenId: tokenId,
      timestamp: block.timestamp,
      owner: msg.sender,
      power: power
    });
    userStacks[msg.sender].push(tokenId);
    hasPaid[tokenId] = 0;
    _addToken(tokenId);
  }

  function unstake(uint256 tokenId) internal {
    require(NFT_CONTRACT.ownerOf(tokenId) == address(this), "Not staked");

    NFT_CONTRACT.safeTransferFrom(address(this), msg.sender, tokenId);
    emit CubieUnstaked(msg.sender, tokenId, block.timestamp);

    delete vault[tokenId];
    delete hasPaid[tokenId];
    _removeToken(tokenId);
    // delete userStacks[msg.sender][tokenId];
  }

  function earnings(uint256 tokenId) public view returns(uint256) {
    Stake memory staked = vault[tokenId];
    require(staked.owner == msg.sender, "Not yours");
    require((staked.timestamp + 1 minutes) < block.timestamp, "Must stake for 24 hrs");
    require(stakeOn == 1, "Paused or Ended");

    uint256 earned = getDailyReward() * ((block.timestamp - staked.timestamp)/(1 minutes));
    uint256 toPay = (earned - hasPaid[tokenId]);

    if (toPay > 0) return toPay;
    else return earned;
  }

  function claim(uint256 tokenId, bool _unstake) external {
    address claimer = payable(msg.sender);
    uint256 earned = earnings(tokenId); // The checks happens here

    if (earned > 0) {
      hasPaid[tokenId] += earned;
      bool success = TOKEN_CONTRACT.transfer(claimer, earned);
      require(success);
      emit RewardClaimed(claimer, earned);
    }
    if(_unstake) unstake(tokenId); 
  }

  function withdrawBalance(address payable _to) public onlyOwner {
    uint256 contract_balance = TOKEN_CONTRACT.balanceOf(address(this));
    bool success = TOKEN_CONTRACT.transfer(_to, contract_balance);
    require(success);
  }
 
  function _forceEarnings(uint256 tokenId) internal view onlyOwner returns(uint256) {
    Stake memory staked = vault[tokenId];
    if ((staked.timestamp + 1 minutes) < block.timestamp) return 0;

    uint256 earned = getDailyReward() * ((block.timestamp - staked.timestamp)/(1 minutes));
    uint256 toPay = (earned - hasPaid[tokenId]);

    if (toPay > 0) return toPay;
    else return earned;
  }

  function _forceClaim(uint256 tokenId) onlyOwner internal returns(uint256) {
    Stake memory staked = vault[tokenId];
    address claimer = payable(staked.owner);
    uint256 earned = _forceEarnings(tokenId);

    if (earned > 0) {
      hasPaid[tokenId] += earned;
      bool success = TOKEN_CONTRACT.transfer(claimer, earned);
      require(success);
    }
    return earned;
  }

  function forceWithdraws() public onlyOwner view returns(uint256[] memory) {
    uint256[] memory allTokens = totalSupplyId();
    uint256[] memory allPaid = new uint[](allTokens.length);
    for (uint i = 0; i < allTokens.length; i++) {
      // uint256 paid = _forceClaim(allTokens[i]);
      allPaid[i] = allTokens[i];
    }
    return allPaid;
  }

  function stopStake() public onlyOwner {
    stakeOn = 0;
  }

  function restartStake() public onlyOwner {
    stakeOn = 1;
  }

  function onERC721Received( address, address, uint256, bytes memory )
  public virtual override returns (bytes4) { return this.onERC721Received.selector; }

  function onTRC721Received( address, address, uint256, bytes memory )
  public virtual override returns (bytes4) { return this.onTRC721Received.selector; }
}