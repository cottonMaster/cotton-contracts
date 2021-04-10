// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./BEP20/BEP20.sol";
import "./utils/SafeMath.sol";
import "./utils/Ownable.sol";
import "./utils/whiteList.sol";

contract CTF is BEP20 {
    using SafeMath for uint256;

    string _name = "Cotton.flowers";
    string _symbol = "CTF";

    constructor () BEP20(_name, _symbol) {
    }

}