//SPDX-License-Identifier: MIT
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

pragma solidity ^0.8.0;

contract MysterySpace {
    using SafeERC20 for IERC20;
    using Address for address payable;

    mapping(uint256 => Mystery) mysteryMapping;
    mapping(uint256 => MysteryReward) mysteryReWardMapping;
    uint256[] public boxIds;
    uint256[] public checkedBoxIds;
    uint256 public currentBoxId;

    struct RequestStatus {
        address sender;
        uint256 boxId;
        uint256 randomWord;
        uint256 randomNumber;
        uint256 timestamp;
        bool fulfilled; // whether the request has been successfully fulfilled
        bool exists; // whether a requestId exists
        bool claimed; // whether reward claimed
    }
    mapping(uint256 => RequestStatus)
        public requestsMapping; 

    // past requests Id.
    uint256[] public requestIds;
    uint256 public lastRequestId;

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
        address owner;
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
            if (i<probabilityArray.length-1){
                require(probabilityArray[i]<probabilityArray[i+1],"Sort from smallest to largest");
            }
            totalProbability = totalProbability + probabilityArray[i];
        }
        require(totalProbability == 10000, "incorrect probability");

        for (uint256 i = 0; i < tokenArray.length; i++) {
            uint256 value = (probabilityArray[i] * totalSupply * rewardAmountArray[i]) / 10000;
            if (tokenArray[i] == address(0)) {
                require(msg.value >= value, "insufficient coin value");
            } else {
                IERC20(tokenArray[i]).safeTransferFrom(msg.sender,address(this),value);
            }
        }

        mysteryMapping[currentBoxId] = Mystery(
            currentBoxId,
            coin,
            price,
            totalSupply,
            totalSupply,
            msg.sender,
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

    function audit(uint boxId) external {
        Mystery storage mystery = mysteryMapping[boxId];
        require(boxId == mystery.boxId,"incorrect box id");
        require(!mystery.checked,"Mystery box already checked");
        mystery.checked = true;
    }

    function mint(uint boxId) external payable{
        Mystery memory mystery = mysteryMapping[boxId];
        require(mystery.checked,"Mystery has not passed the review");
        require(mystery.stocks > 0,"Insufficient stocks");

        if (mystery.coin == address(0)){
            require(msg.value >= mystery.price, "Insufficient coin value");
        }else{
            IERC20(mystery.coin).safeTransferFrom(msg.sender,address(this),mystery.price);
        }
        requestRandomWords(boxId);
    }

    function requestRandomWords(uint boxId)
        internal
        returns (uint256 requestId)
    {
        
        requestId = block.timestamp;
        requestsMapping[requestId] = RequestStatus({
            sender: msg.sender,
            boxId: boxId,
            randomWord: 0,
            randomNumber: 0xfffff,
            timestamp: 0,
            exists: true,
            fulfilled: false,
            claimed: false
        });
        requestIds.push(requestId);
        lastRequestId = requestId;
    }

    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] memory _randomWords
    ) public  {
        require(requestsMapping[_requestId].exists, "request not found");
        RequestStatus storage requestStatus = requestsMapping[_requestId];
        requestStatus.fulfilled = true;
        requestStatus.randomWord = _randomWords[0];
        requestStatus.timestamp = block.timestamp;
        requestStatus.randomNumber = uint256(keccak256(abi.encodePacked(requestStatus.sender, requestStatus.timestamp,requestStatus.randomWord)) >> 236);
    }

    function claimed(uint requestId) external {
        RequestStatus storage requestStatus = requestsMapping[requestId];
        requestStatus.claimed = true;
        uint randomNumber = requestStatus.randomNumber;
        MysteryReward memory mysteryReward = mysteryReWardMapping[requestStatus.boxId];
        for (uint i = 0;i<mysteryReward.rangeArray.length;i++){
            if (randomNumber < mysteryReward.rangeArray[i]){
                address token = mysteryReward.tokenArray[i];
                if (token == address(0)){
                    payable(msg.sender).sendValue(mysteryReward.rewardAmountArray[i]);
                }else {
                    IERC20(token).safeTransferFrom(address(this),msg.sender,mysteryReward.rewardAmountArray[i]);
                }
                return;
            }
        }

    } 

    function getRandomNumber() public returns (uint256 random) {
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
