//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Helper {

    mapping(uint256 => Mystery) mysteryMapping;
    mapping(uint256 => MysteryReward)  mysteryReWardMapping;
    uint256[] public boxIds;
    uint256[] public checkedBoxIds;
    uint256 public currentBoxId;


    struct Mystery {
        uint256 boxId;
        address coin;
        uint256 price;
        uint256 totalSupply;
        uint256 stocks;
        bool checked;
    }

    function getBoxDetail(uint boxId) public view returns(uint256[] memory probabilityArray,uint256[] memory rangeArray){
        MysteryReward memory mysteryReward =  mysteryReWardMapping[boxId];
        probabilityArray = mysteryReward.probabilityArray;
        rangeArray = mysteryReward.rangeArray;
    }

    struct MysteryReward {
        uint256[] probabilityArray;
        uint256[] rangeArray;
        address[] tokenArray;
        uint256[] rewardAmountArray;
    }
    uint256[] public range;

    function getAddress0() public pure returns(address){
        return address(0);
    }

    function coin() public pure returns(uint){
        return 0.1 ether;
    }

     function publishMysteryBox(

        uint256[] memory probabilityArray
    ) public  {

        uint totalProbability;
        for(uint i=0;i<probabilityArray.length;i++){

            totalProbability = totalProbability + probabilityArray[i];
        }
        require(totalProbability == 10000,"incorrect probability");

        MysteryReward storage mysteryReward = mysteryReWardMapping[currentBoxId];
        uint[] storage rangeArray = mysteryReward.rangeArray;
        for(uint i=0;i<probabilityArray.length;i++){

            uint border = probabilityArray[i] * 0xfffff / 10000;
            if (i ==0){
                rangeArray.push(border);
            } else if (i == probabilityArray.length-1) {
                rangeArray.push(0xfffff);
            }else {
                rangeArray.push(rangeArray[i-1] + border);
            }
        }
        mysteryReward.probabilityArray = probabilityArray;
    

        boxIds.push(currentBoxId);
        currentBoxId++;
    }
}