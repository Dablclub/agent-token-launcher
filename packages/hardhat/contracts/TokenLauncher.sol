// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./LaunchToken.sol";

interface ILaunchToken is IERC20 {
    function owner() external view returns (address);
}

contract TokenLauncher is Ownable {
    // Structs
    struct TokenConfig {
        string name;
        string symbol;
        uint256 totalSupply;
        uint256 fid;
        string imageUrl;
        string socialProof;
        bytes32 salt;
    }

    struct PreSale {
        uint256 tokenPrice; // Price per token in ETH
        uint256 minPurchase; // Minimum purchase in tokens
        uint256 maxPurchase; // Maximum purchase in tokens
        uint256 startTime;
        uint256 endTime;
        uint256 tokensForSale;
        uint256 tokensSold;
        bool finalized;
        address tokenAddress;
    }

    // Events
    event TokenCreated(
        address indexed tokenAddress,
        address indexed creator,
        string name,
        string symbol,
        uint256 totalSupply
    );

    event PreSaleCreated(
        address indexed tokenAddress,
        uint256 tokenPrice,
        uint256 tokensForSale,
        uint256 startTime,
        uint256 endTime
    );

    event TokensPurchased(address indexed buyer, address indexed tokenAddress, uint256 amount, uint256 pricePaid);

    // Mappings
    mapping(address => PreSale) public presales;
    mapping(address => address[]) public userTokens;

    constructor(address initialOwner) Ownable(initialOwner) {}

    function createToken(TokenConfig calldata config) external returns (address) {
        bytes32 deploySalt = keccak256(abi.encode(msg.sender, config.salt));

        LaunchToken token = new LaunchToken{ salt: deploySalt }(
            config.name,
            config.symbol,
            config.totalSupply,
            msg.sender,
            config.fid,
            config.imageUrl,
            config.socialProof
        );

        address tokenAddress = address(token);
        userTokens[msg.sender].push(tokenAddress);

        emit TokenCreated(tokenAddress, msg.sender, config.name, config.symbol, config.totalSupply);

        return tokenAddress;
    }

    function createPreSale(
        address tokenAddress,
        uint256 tokenPrice,
        uint256 minPurchase,
        uint256 maxPurchase,
        uint256 tokensForSale,
        uint256 startTime,
        uint256 duration
    ) external {
        require(IERC20(tokenAddress).balanceOf(msg.sender) >= tokensForSale, "Insufficient tokens");
        require(startTime >= block.timestamp, "Invalid start time");
        require(duration > 0, "Invalid duration");
        require(tokenPrice > 0, "Invalid price");
        require(tokensForSale > 0, "Invalid amount");
        require(maxPurchase >= minPurchase, "Invalid purchase limits");

        PreSale storage sale = presales[tokenAddress];
        require(!sale.finalized, "PreSale exists");

        // Transfer tokens to contract
        IERC20(tokenAddress).transferFrom(msg.sender, address(this), tokensForSale);

        sale.tokenPrice = tokenPrice;
        sale.minPurchase = minPurchase;
        sale.maxPurchase = maxPurchase;
        sale.startTime = startTime;
        sale.endTime = startTime + duration;
        sale.tokensForSale = tokensForSale;
        sale.tokenAddress = tokenAddress;

        emit PreSaleCreated(tokenAddress, tokenPrice, tokensForSale, startTime, sale.endTime);
    }

    function buyTokens(address tokenAddress, uint256 tokenAmount) external payable {
        PreSale storage sale = presales[tokenAddress];
        require(block.timestamp >= sale.startTime, "Not started");
        require(block.timestamp <= sale.endTime, "Ended");
        require(!sale.finalized, "Finalized");
        require(tokenAmount >= sale.minPurchase, "Below min purchase");
        require(tokenAmount <= sale.maxPurchase, "Above max purchase");
        require(tokenAmount <= sale.tokensForSale - sale.tokensSold, "Exceeds available");

        uint256 cost = (tokenAmount * sale.tokenPrice) / 1e18;
        require(msg.value >= cost, "Insufficient payment");

        sale.tokensSold += tokenAmount;
        IERC20(tokenAddress).transfer(msg.sender, tokenAmount);

        emit TokensPurchased(msg.sender, tokenAddress, tokenAmount, cost);

        // Return excess payment
        if (msg.value > cost) {
            payable(msg.sender).transfer(msg.value - cost);
        }
    }

    function finalizePreSale(address tokenAddress) external {
        PreSale storage sale = presales[tokenAddress];
        require(msg.sender == ILaunchToken(tokenAddress).owner(), "Not owner");
        require(block.timestamp > sale.endTime || sale.tokensSold == sale.tokensForSale, "Not ended");
        require(!sale.finalized, "Already finalized");

        sale.finalized = true;

        // Return unsold tokens to owner
        if (sale.tokensSold < sale.tokensForSale) {
            uint256 unsold = sale.tokensForSale - sale.tokensSold;
            IERC20(tokenAddress).transfer(msg.sender, unsold);
        }

        // Transfer collected ETH to owner
        uint256 balance = address(this).balance;
        if (balance > 0) {
            payable(msg.sender).transfer(balance);
        }
    }

    // View functions
    function getPreSaleInfo(address tokenAddress) external view returns (PreSale memory) {
        return presales[tokenAddress];
    }

    function getUserTokens(address user) external view returns (address[] memory) {
        return userTokens[user];
    }
}
