pragma solidity ^ 0.6.0;

/**
 * @title TRC721 token receiver interface
 * @dev Interface for any contract that wants to support safeTransfers
 * from TRC721 asset contracts.
 */
interface TRC721TokenReceiver {
    function onTRC721Received(address  _operator, address _from, uint256 _tokenId, bytes memory _data) external returns(bytes4);
}

contract CubieStacking is TRC721TokenReceiver {
  
  address public TOKEN_CONTRACT;
  address public NFT_CONTRACT;
  
  address public admin;
  uint256 public totalStaked;
  uint256 public dailyReward;

  struct Stake{
    uint256 tokenId;
    uint256 timestamp;
    address owner;
    uint256 power;
  }

  event CubieStaked(address indexed owner, uint256 tokenId, uint256 value);
  event CubieUnstaked(address indexed owner, uint256 tokenId, uint256 value);
  event RewardClaimed(address owner, uint256 reward);

  mapping(uint256 => Stake) public vault;

  constructor (address _Token, address _NFT) public {
    TOKEN_CONTRACT = _Token;
    NFT_CONTRACT = _NFT;

    admin = msg.sender;
    setDailyReward(10000000);
  }

  function setDailyReward(uint256 value) public returns(string memory) {
    require(msg.sender == admin, "Only admin can set daily reward");
    dailyReward = value;
    return "Daily reward set";
  }

  function getDailyReward() public view returns(uint256) {
    return dailyReward;
  }

  function stake(uint256[] calldata tokenIds, uint256 power) external {
    uint256 tokenId;
    totalStaked += tokenIds.length;
    for (uint i = 0; i <= tokenIds.length; i++) {
      tokenId = tokenIds[i];
      require(NFT_CONTRACT.ownerOf(tokenId) == msg.sender, "You can only stake your own token");
      require(vault[tokenId].tokenId == 0, "You can only stake once");
      require(power[i] < 4, "Invalid mining power");
      
      NFT_CONTRACT.safeTransferFrom(msg.sender, address(this), tokenId);
      emit CubieStaked(msg.sender, tokenId, block.timestamp);

      vault[tokenId] = Stake({
        tokenId: tokenId,
        timestamp: block.timestamp,
        owner: msg.sender,
        power: power[i]
      });

    }
  }

  function unstake(address account, uint256[] memory tokenIds) internal {
    uint256 tokenId;
    totalStaked -= tokenIds.length;
    for (uint i = 0; i <= tokenIds.length; i++) {
      tokenId = tokenIds[i];

      Stake memory staked = vault[tokenId];
      require(staked.owner == msg.sender, "You can only unstake your own token");
      require(NFT_CONTRACT.ownerOf(tokenId) == address(this), "This token is not staked");

      NFT_CONTRACT.safeTransferFrom(address(this), account, tokenId);
      emit CubieUnstaked(msg.sender, tokenId, block.timestamp);

      delete vault[tokenId];
    }
  }

  function earnings(address account, uint256 tokenId) public returns(uint256) {
    uint256 earned = 0;
      
    Stake memory staked = vault[tokenId];
    require(staked.owner == account, "You can only claim from your own token");
    // Making it 1 mins for testing 
    require(staked.timestamp + 60 * 60 < block.timestamp, "Token must be staked for atleast 24 hrs");
    // 24*
    require(NFT_CONTRACT.ownerOf(tokenId) == msg.sender, "Not your token");
    // Calculate the reward
    earned += getDailyReward() * staked.power * (block.timestamp - staked.timestamp) / 1 days;
    return earned;
  }

  function claim(address payable account, uint256[] calldata tokenIds, bool _unstake) external {
    
    for (uint i = 0; i <= tokenIds.length; i++) {
      
      uint256 earned = earnings(account, tokenIds[i]);

      if (earned > 0) {
        TOKEN_CONTRACT.transferFrom(owner, account, earned);
        
        emit RewardClaimed(account, earned);
      }
    }

    if (_unstake) {
      unstake(account, tokenIds);
    }
  }

}