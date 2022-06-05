pragma solidity ^0.5.0;

contract Ownable {
    address private _owner;
    constructor () internal {
      _owner = msg.sender;
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(owner() == _owner, "Ownable: caller is not the owner");
        _;
    }
}

interface ITRC165 {
  function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

contract ITRC721 is ITRC165 {
    function ownerOf(uint256 tokenId) public view returns (address owner);
    function safeTransferFrom(address from, address to, uint256 tokenId) public;
}

contract ITRC721Receiver {
    function onTRC721Received(address operator, address from, uint256 tokenId, bytes memory data)
    public returns (bytes4);
}

contract TRC165 is ITRC165 {
    bytes4 private constant _INTERFACE_ID_TRC165 = 0x01ffc9a7;
    mapping(bytes4 => bool) private _supportedInterfaces;
    constructor () internal {
      _registerInterface(_INTERFACE_ID_TRC165);
    }
    
    function supportsInterface(bytes4 interfaceId) external view returns (bool) {
      return _supportedInterfaces[interfaceId];
    }
    function _registerInterface(bytes4 interfaceId) internal {
      require(interfaceId != 0xffffffff, "TRC165: invalid interface id");
      _supportedInterfaces[interfaceId] = true;
    }
}

contract ITRC20 {
    function transferFrom(address from, address to, uint256 amount) public returns (bool);
}

contract TRC721 is TRC165, ITRC721 {

  bytes4 private constant _TRC721_RECEIVED = 0x5175f878;
  bytes4 private constant _INTERFACE_ID_TRC721 = 0x80ac58cd;
  constructor () public {
    // register the supported interfaces to conform to TRC721 via TRC165
    _registerInterface(_INTERFACE_ID_TRC721);
  }

  
  function _checkOnTRC721Received(address from, address to, uint256 tokenId, bytes memory _data) internal returns(bool)
  {
    if (!to.isContract) {
      return true;
    }
    // solhint-disable-next-line avoid-low-level-calls
    (bool success, bytes memory returndata) = to.call(abi.encodeWithSelector(
      ITRC721Receiver(to).onTRC721Received.selector,
      msg.sender, from, tokenId, _data
    ));
    if (!success) {
      if (returndata.length > 0) {
          // solhint-disable-next-line no-inline-assembly
          assembly {
          let returndata_size:= mload(returndata)
          revert(add(32, returndata), returndata_size)
        }
      } else {
        revert("TRC721: transfer to non TRC721Receiver implementer");
      }
    } else {
      bytes4 retval = abi.decode(returndata, (bytes4));
      return (retval == _TRC721_RECEIVED);
    }
  }
}

contract CubieStacking is TRC721, Ownable, ITRC721Receiver {
  
  address public TOKEN_CONTRACT;
  address public NFT_CONTRACT;
  
  uint256 public totalStaked;
  uint256 public dailyReward = 10000000;

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
    
    // setDailyReward(10000000);
  }

  function setDailyReward(uint256 value) public onlyOwner returns(string memory) {
    dailyReward = value;
    return "Daily reward set";
  }

  function getDailyReward() public view returns(uint256) {
    return dailyReward;
  }

  function stake(uint256[] calldata tokenIds, uint256[] calldata power) external {
    uint256 tokenId;
    totalStaked += tokenIds.length;
    for (uint i = 0; i <= tokenIds.length; i++) {
      tokenId = tokenIds[i];
      require(ITRC721(NFT_CONTRACT).ownerOf(tokenId) == msg.sender, "You can only stake your own token");
      require(vault[tokenId].tokenId == 0, "You can only stake once");
      require(power[i] < 4, "Invalid mining power");
      
      require(_checkOnTRC721Received(msg.sender, address(this), tokenId, ""), "TRC721: transfer to non TRC721Receiver implementer");

      ITRC721(NFT_CONTRACT).safeTransferFrom(msg.sender, address(this), tokenId); 
      ITRC721(NFT_CONTRACT).safeTransferFrom(msg.sender, address(this), tokenId);
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
      require(ITRC721(NFT_CONTRACT).ownerOf(tokenId) == address(this), "This token is not staked");

      ITRC721(NFT_CONTRACT).safeTransferFrom(address(this), account, tokenId);
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
    require(ITRC721(NFT_CONTRACT).ownerOf(tokenId) == msg.sender, "Not your token");
    // Calculate the reward
    earned += getDailyReward() * staked.power * (block.timestamp - staked.timestamp) / 1 days;
    return earned;
  }

  function claim(address payable claimer, uint256[] calldata tokenIds, bool _unstake) external {
    
    for (uint i = 0; i <= tokenIds.length; i++) {
      
      uint256 earned = earnings(claimer, tokenIds[i]);

      if (earned > 0) {
        bool success = ITRC20(TOKEN_CONTRACT).transferFrom(owner(), claimer, earned);
        require(success);
        emit RewardClaimed(claimer, earned);
      }
    }

    if (_unstake) {
      unstake(claimer, tokenIds);
    }
  }

}