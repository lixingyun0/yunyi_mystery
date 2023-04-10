//SPDX-License-Identifier: MIT
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

pragma solidity ^0.8.0;

contract MysterySpace {
    using SafeERC20 for IERC20;

    mapping(uint256 => Mystery) mysteryMapping;
    mapping(uint256 => MysteryReward) mysteryReWardMapping;
    uint256[] public boxIds;
    uint256[] public checkedBoxIds;
    uint256 public currentBoxId;

    event Log(
        address sender,
        uint256 time,
        bytes32 a,
        bytes32 b,
        uint256 random
    );

    struct Mystery {
        uint256 boxId;
        address coin;
        uint256 price;
        uint256 totalSupply;
        uint256 stocks;
        bool checked;
    }

    struct MysteryReward {
        uint256[] probabilityArray;
        uint256[] rangeArray;
        address[] tokenArray;
        uint256[] rewardAmountArray;
    }

    function getBoxDetail(uint256 boxId)
        public
        view
        returns (
            address coin,
            uint256 price,
            uint256 totalSupply,
            uint256 stocks,
            bool checked,
            uint256[] memory probabilityArray,
            uint256[] memory rangeArray,
            address[] memory tokenArray,
            uint256[] memory rewardAmountArray
        )
    {
        Mystery memory mystery = mysteryMapping[boxId];
        coin = mystery.coin;
        price = mystery.price;
        totalSupply = mystery.totalSupply;
        stocks = mystery.stocks;
        checked = mystery.checked;
        
        MysteryReward memory mysteryReward = mysteryReWardMapping[boxId];
        probabilityArray = mysteryReward.probabilityArray;
        rangeArray = mysteryReward.rangeArray;
        tokenArray = mysteryReward.tokenArray;
        rewardAmountArray = mysteryReward.rewardAmountArray;
    }

    function publishMysteryBox(
        address coin,
        uint256 price,
        uint256 totalSupply,
        uint256[] memory probabilityArray,
        address[] memory tokenArray,
        uint256[] memory rewardAmountArray
    ) public payable {
        require(price > 0, "price must > 0");
        require(totalSupply > 0, "totalSupply must > 0");
        require(
            probabilityArray.length > 0 &&
                tokenArray.length > 0 &&
                rewardAmountArray.length > 0,
            "incorrect parameter"
        );
        require(
            probabilityArray.length == tokenArray.length &&
                tokenArray.length == rewardAmountArray.length,
            "incorrect parameter"
        );
        uint256 totalProbability;
        for (uint256 i = 0; i < probabilityArray.length; i++) {
            totalProbability = totalProbability + probabilityArray[i];
        }
        require(totalProbability == 10000, "incorrect probability");

        for (uint256 i = 0; i < tokenArray.length; i++) {
            uint256 value = (probabilityArray[i] *
                totalSupply *
                rewardAmountArray[i]) / 10000;
            if (tokenArray[i] == address(0)) {
                require(msg.value >= value, "insufficient coin value");
            } else {
                IERC20(tokenArray[i]).safeTransferFrom(
                    msg.sender,
                    address(this),
                    value
                );
            }
        }

        mysteryMapping[currentBoxId] = Mystery(
            currentBoxId,
            coin,
            price,
            totalSupply,
            totalSupply,
            false
        );
        MysteryReward storage mysteryReward = mysteryReWardMapping[
            currentBoxId
        ];
        uint256[] storage rangeArray = mysteryReward.rangeArray;
        for (uint256 i = 0; i < probabilityArray.length; i++) {
            uint256 border = (probabilityArray[i] * 0xfffff) / 10000;
            if (i == 0) {
                rangeArray.push(border);
            } else if (i == probabilityArray.length - 1) {
                rangeArray.push(0xfffff);
            } else {
                rangeArray.push(rangeArray[i - 1] + border);
            }
        }
        mysteryReward.probabilityArray = probabilityArray;
        mysteryReward.tokenArray = tokenArray;
        mysteryReward.rewardAmountArray = rewardAmountArray;

        boxIds.push(currentBoxId);
        currentBoxId++;
    }

    function requestRandomNumber() public returns (uint256 random) {
        address sender = msg.sender;
        uint256 time = block.timestamp;
        bytes32 randomBytes1 = keccak256(abi.encodePacked(time, sender));
        bytes32 randomBytes2 = randomBytes1 >> 236;
        random = uint256(randomBytes2);
        emit Log(sender, time, randomBytes1, randomBytes2, random);
    }

    function getMysteryAmount(bool checked)
        public
        view
        returns (uint256 amount)
    {
        if (checked) {
            amount = checkedBoxIds.length;
        } else {
            amount = boxIds.length;
        }
    }
}
