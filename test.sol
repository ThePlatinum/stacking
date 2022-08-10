// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Rewards
{
  uint256 internal reward = 10 ether;

  function setReward(uint256 value) public {
    reward = value * 1 ether;
  }

  function getReward(uint256 value) public view returns(uint256) {
    return reward;
  }
}