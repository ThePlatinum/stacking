pragma solidity ^0.5.0;

import "./cubie-contract.sol";

contract ITRC721Receiver {
    function onTRC721Received(address operator, address from, uint256 tokenId, bytes memory data)
    public returns (bytes4);
}

contract CubieStacking is Ownable, ITRC721Receiver {

  address public admin;
  uint256 public totalStaked;

  struct Stake{
    uint256 tokenId;
    uint256 timestamp;
    address owner;
  }
    
  event CubieStaked(address indexed owner, uint256 tokenId, uint256 value);
  event CubieUnstaked(address indexed owner, uint256 tokenId, uint256 value);
  event RewardClaimed(address owner, uint256 reward);

  address public constant TOKEN_CONTRACT = address(0x624018ef691468fe66a307a077f39dc208e13910);
  address public constant NFT_CONTRACT = address(0x58940b5fb48f9836993ecf7dd4d5d72748be317d);
  
  Cubie NFT;

  mapping (uint256 => Stake) public vault;

  // Constructor
  constructor() public {

    admin = msg.sender;

    NFT = Cubie(NFT_CONTRACT);

    setDailyReward(10000000);
  }

  function setDailyReward(uint256 value) public returns(string memory) {
    require(msg.sender == admin, "Only admin can set daily reward");
    dailyReward = value;
    return "Daily reward set to " + dailyReward;
  }

  function getDailyReward() public view returns(uint256) {
    return dailyReward;
  }

  function stake(uint256[] calldata tokenIds, uint256 power) external {
    uint256 tokenId;
    totalStaked += tokenIds.length;
    for (uint i = 0; i <= tokenIds.length; i++) {
      tokenId = tokenIds[i];
      require(NFT.ownerOf(tokenId) == msg.sender, "You can only stake your own token");
      require(vault[tokenId].tokenId == 0, "You can only stake once");
      require(power[i] < 4, "Invalid mining power");
      
      require(_checkOnTRC721Received(msg.sender, address(this), tokenId, ""), "TRC721: transfer to non TRC721Receiver implementer");

      NFT.safeTransferFrom(msg.sender, address(this), tokenId);
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
      for (uint i = 0; i<=tokenIds.length; i++){
        tokenId = tokenIds[i];

        Stake memory staked = vault[tokenId];
        require(staked.owner == msg.sender, "You can only unstake your own token");
        require(NFT.ownerOf(tokenId) == address(this), "This token is not staked");
        
        NFT.safeTransferFrom(address(this), account, tokenId);
        emit CubieUnstaked(msg.sender, tokenId, block.timestamp);

        delete vault[tokenId];
      }
    }

  function earnings(address account, uint256 tokenId) public returns(uint256) {
    uint256 earned = 0;
    Stake memory staked = vault[tokenId];
    require(staked.owner == account, "You can only claim from your own token");
    require(staked.timestamp + 60 * 60 < block.timestamp, "Token must be staked for atleast 24 hrs");
    // 24*
    require(NFT.ownerOf(tokenId) == address(this), "This token is not staked");

    earned += getDailyReward() * staked.power * (block.timestamp - staked.timestamp) / 1 days;
    return earned;
  }

  function claim(address payable account, uint256[] calldata tokenIds, bool _unstake) external {
    
    for (uint i = 0; i <= tokenIds.length; i++) {
      
      uint256 earned = earnings(account, tokenIds[i]);

      if (earned > 0) {
        (bool success, bytes memory returnData) = TOKEN_CONTRACT.call(
          abi.encodeWithSignature("transfer(address,uint256)", account, earned)
        );
        require(success);
      }
      emit RewardClaimed(account, earned);
    }

    if (_unstake) {
      unstake(account, tokenIds);
    }
  }

}