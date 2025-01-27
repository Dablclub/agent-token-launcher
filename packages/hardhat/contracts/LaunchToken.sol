// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LaunchToken is ERC20, Ownable {
    string public imageUrl;
    uint256 public fid; // Farcaster ID
    string public socialProof; // Cast hash or other proof

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 totalSupply_,
        address owner_,
        uint256 fid_,
        string memory imageUrl_,
        string memory socialProof_
    ) ERC20(name_, symbol_) Ownable(owner_) {
        _mint(owner_, totalSupply_);
        fid = fid_;
        imageUrl = imageUrl_;
        socialProof = socialProof_;
    }
}
