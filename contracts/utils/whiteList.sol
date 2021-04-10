// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./Ownable.sol";

contract whiteList is Ownable {
    mapping(address => bool) private allowedMinters;

    constructor () {
        allowedMinters[_msgSender()] = true;
    }
    
    event _addMinter(address indexed minter);
    event _removeMinter(address indexed minter);
    
    function isMinter(address minter) public view returns (bool){
        return allowedMinters[minter];
    }

    function addMinter(address minter) public onlyOwner returns (bool success) {
        allowedMinters[minter] = true;
        emit _addMinter(minter);
        
        return true;
    }

    function removeMinter(address minter) public onlyOwner returns (bool success) {
        allowedMinters[minter] = false;
        emit _removeMinter(minter);
        
         return true;
    }

    modifier onlyAllowedMinter() {
        require(allowedMinters[_msgSender()] == true, "White List: not a minter");
        _;
    }
}