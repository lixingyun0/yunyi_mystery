//SPDX-License-Identifier: MIT
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

pragma solidity ^0.8.0;

contract MysterySpace {
    using SafeERC20 for IERC20;

    mapping(uint256 => Mystery) mysteryMapping;
    mapping(uint256 => MysteryReward) mysteryReWardMapping;
    uint256[] boxIds;
    uint256[] checkedBoxIds;
    uint256 boxId;

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
        require(probabilityArray.length>0 && tokenArray.length>0 && rewardAmountArray.length>0, "incorrect parameter");
        require(probabilityArray.length == tokenArray.length && tokenArray.length == rewardAmountArray.length, "incorrect parameter");
        uint totalProbability

        for(uint i=0;i<tokenArray.length;i++){
            if (tokenArray[i] == address(0)){
                require(msg.value >= probabilityArray[i] * totalSupply * rewardAmountArray[i] /10000)
            }else{

            }
        }
        mysteryMapping[boxId] = Mystery(boxId,coin,price,totalSupply,totalSupply,false);
        mysteryReWardMapping[boxId] = MysteryReward(range,tokenArray,amountArray);
        boxIds.push(boxId);
        boxId++;
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
