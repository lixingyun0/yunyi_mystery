// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.5.9;

import "@0x/contracts-erc20/contracts/src/ERC20Token.sol";

/**
 * @title SampleERC20
 * @dev Create a sample ERC20 standard token
 */
contract XusdERC20 is ERC20Token {

    string public name;
    string public symbol;
    uint256 public decimals;

    constructor (

    )
        public
    {
        name = 'YunYiUSD';
        symbol = 'XUSD';
        decimals = 6;
        _totalSupply = 1000000000000;
        balances[msg.sender] = 1000000000000;
    }
}