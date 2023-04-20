//SPDX-License-Identifier: MIT
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";


pragma solidity 0.8.18;

contract MysterySpaceChainlink is VRFConsumerBaseV2, ConfirmedOwner, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Address for address payable;

    mapping(uint256 => Mystery) mysteryMapping;
    mapping(uint256 => MysteryReward) mysteryReWardMapping;
    uint256[] public boxIds;
    uint256[] public checkedBoxIds;
    uint256 public currentBoxId;
    mapping(uint256 => mapping(address => uint256)) boxAccount;
    mapping(uint256 => mapping(address => uint256)) boxRewardAmountMapping;

    //chainlink
    VRFCoordinatorV2Interface COORDINATOR;
    uint64 chainlink_subscription_id;
    bytes32 chainlink_key_hash = 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c;
    uint32 chainlink_callback_gas_limit = 300000;
    uint16 chainlink_request_confirmations = 3;
    uint32 chaink_num_words = 1;

    /**
     * HARDCODED FOR SEPOLIA
     * COORDINATOR: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625
     */
    constructor(
        uint64 subscriptionId,
        address coordinator
    )
        VRFConsumerBaseV2(coordinator)
        ConfirmedOwner(msg.sender)
    {
        COORDINATOR = VRFCoordinatorV2Interface(coordinator);
        chainlink_subscription_id = subscriptionId;
    }

    struct RequestStatus {
        address sender;
        uint256 boxId;
        uint256 randomWord;
        uint256 randomNumber;
        uint256 timestamp;
        address rewardToken;
        uint256 rewardAmount;
        bool fulfilled; // whether the request has been successfully fulfilled
        bool exists; // whether a requestId exists
        bool claimed; // whether reward claimed
    }
    mapping(uint256 => RequestStatus) public requestsMapping;

    uint256[] public requestIds;

    error InsufficientTokenValue(address token);

    event PublishMystery(uint boxId);

    event Mint(uint boxId);
    
    event Claim(uint requestId);

    event Deposit(uint boxId);

    event StopSale(uint boxId);

    event PushLisherClaim(uint boxId);

    event Audit(uint boxId);

    event Freeze(uint boxId);

    event UnFreeze(uint boxId);

    event RequestSent(uint256 boxId, uint256 requestId);
    event RequestFulfilled(uint256 requestId, uint256 randomWord);


    struct Mystery {
        uint256 boxId;
        address coin;
        uint256 price;
        uint256 totalSupply;
        uint256 stocks;
        uint256 income;
        address owner;
        bool frozen;
        bool checked;
        bool stop;
    }

    struct MysteryReward {
        uint256[] probabilityArray;
        uint256[] rangeArray;
        address[] tokenArray;
        uint256[] rewardAmountArray;
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

    function getBoxAccountInfo(uint256 boxId,address token) external view returns (uint256){
        return boxAccount[boxId][token];
    }

    function getBoxInfo(uint256 _boxId)
        public
        view
        returns (
            address coin,
            uint256 price,
            uint256 totalSupply,
            uint256 stocks,
            uint256 income,
            address owner,
            bool frozen,
            bool checked,
            bool stop
        )
    {
        Mystery memory mystery = mysteryMapping[_boxId];
        coin = mystery.coin;
        price = mystery.price;
        totalSupply = mystery.totalSupply;
        stocks = mystery.stocks;
        income = mystery.income;
        owner = mystery.owner;
        frozen = mystery.frozen;
        checked = mystery.checked;
        stop = mystery.stop;
        
    }

    function getBoxRewardInfo(uint256 boxId)
        public
        view
        returns (
            uint256[] memory probabilityArray,
            uint256[] memory rangeArray,
            address[] memory tokenArray,
            uint256[] memory rewardAmountArray
        )
    {
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
            if (i < probabilityArray.length - 1) {
                require(
                    probabilityArray[i] <= probabilityArray[i + 1],
                    "Sort from smallest to largest"
                );
            }
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
            boxAccount[currentBoxId][tokenArray[i]] = value;
            boxRewardAmountMapping[currentBoxId][
                tokenArray[i]
            ] = rewardAmountArray[i];
        }

        mysteryMapping[currentBoxId] = Mystery({
            boxId: currentBoxId,
            coin: coin,
            price: price,
            totalSupply: totalSupply,
            stocks: totalSupply,
            owner: msg.sender,
            income: 0,
            checked: false,
            frozen: false,
            stop: false
        });

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
        emit PublishMystery(currentBoxId);
        currentBoxId++;

    }

    function deposit(
        uint256 boxId,
        address[] memory _tokenArray,
        uint256[] memory _amountArray
    ) external payable {
        require(_tokenArray.length > 0, "At least one token address");
        require(
            _tokenArray.length == _amountArray.length,
            "Incorrect parameter"
        );
        MysteryReward memory mysteryReward = mysteryReWardMapping[boxId];

        for (uint256 i = 0; i < _tokenArray.length; i++) {
            address token = _tokenArray[i];
            uint256 amount = _amountArray[i];

            if (token == address(0)) {
                require(msg.value >= amount, "insufficient coin value");
            } else {
                IERC20(token).safeTransferFrom(
                    msg.sender,
                    address(this),
                    amount
                );
            }
            boxAccount[boxId][token] = boxAccount[boxId][token] + amount;
        }
        address[] memory tokenArray = mysteryReward.tokenArray;
        uint256[] memory rewardAmountArray = mysteryReward.rewardAmountArray;

        mapping(address => uint256) storage boxAccountMapping = boxAccount[boxId];
        bool frozen = false;
        for (uint256 i = 0; i < tokenArray.length; i++) {
            address token = tokenArray[i];
            uint256 amount = rewardAmountArray[i];
            if (boxAccountMapping[token] < amount) {
                frozen = true;
                break;
            }
        }
        if (!frozen) {
            mysteryMapping[boxId].frozen = false;
            emit UnFreeze(boxId);
        }
        emit Deposit(boxId);
    }

    function stopSaleMystery(uint256 boxId) external nonReentrant {
        Mystery storage mystery = mysteryMapping[boxId];
        require(mystery.owner == msg.sender, "Not mystery owner");
        mystery.stop = true;
        MysteryReward memory mysteryReward = mysteryReWardMapping[boxId];
        address[] memory tokenArray = mysteryReward.tokenArray;
        mapping(address => uint256) storage _account = boxAccount[boxId];
        for (uint256 i = 0; i < tokenArray.length; i++) {
            uint256 _amount = _account[tokenArray[i]];
            if (_amount > 0) {
                _account[tokenArray[i]] = 0;
                if (tokenArray[i] == address(0)) {
                    payable(msg.sender).sendValue(_amount);
                } else {
                    IERC20(tokenArray[i]).safeTransfer(msg.sender, _amount);
                }
            }
        }
        emit StopSale(boxId);
    }

    function claimedMysteryIncome(uint256 boxId) external nonReentrant {
        Mystery storage mystery = mysteryMapping[boxId];
        require(mystery.owner == msg.sender, "Not mystery owner");
        uint256 _income = mystery.income;
        if (_income > 0) {
            mystery.income = 0;
            if (mystery.coin == address(0)) {
                payable(msg.sender).sendValue(_income);
            } else {
                IERC20(mystery.coin).safeTransfer(msg.sender, _income);
            }
        }
        emit PushLisherClaim(boxId);
    }

    function audit(uint256 boxId) external onlyOwner{
        Mystery storage mystery = mysteryMapping[boxId];
        require(boxId == mystery.boxId, "incorrect box id");
        require(!mystery.checked, "Mystery box already checked");
        mystery.checked = true;
        checkedBoxIds.push(boxId);
        emit Audit(boxId);
    }

    //=============================================================

    function mint(uint256 boxId) external payable {
        Mystery storage mystery = mysteryMapping[boxId];
        require(mystery.checked, "Mystery has not passed the review");
        require(mystery.stocks > 0, "Insufficient stocks");
        require(!mystery.frozen, "Insufficient reward");
        require(!mystery.stop, "Stop sale");

        mystery.stocks--;
        if (mystery.coin == address(0)) {
            require(msg.value >= mystery.price, "Insufficient coin value");
        } else {
            IERC20(mystery.coin).safeTransferFrom(
                msg.sender,
                address(this),
                mystery.price
            );
        }
        
        mystery.income = mystery.income + mystery.price;
        requestRandomWords(boxId);
        emit Mint(boxId);
    }

    function claimed(uint256 requestId) external nonReentrant {
        RequestStatus storage requestStatus = requestsMapping[requestId];
        require(requestStatus.fulfilled,"Wait chainlink fullfill random words");
        require(!requestStatus.claimed,"Reward claimed");
        require(requestStatus.sender == msg.sender,"Only callable by request sender");
        requestStatus.claimed = true;
        
        if (requestStatus.rewardToken == address(0)) {
            payable(msg.sender).sendValue(requestStatus.rewardAmount);
        } else {
            IERC20(requestStatus.rewardToken).safeTransfer(
                msg.sender,
                requestStatus.rewardAmount
            );
        }
    }

    function requestRandomWords(uint256 boxId)
        internal
        returns (uint256 requestId)
    {
        requestId = COORDINATOR.requestRandomWords(
            chainlink_key_hash,
            chainlink_subscription_id,
            chainlink_request_confirmations,
            chainlink_callback_gas_limit,
            chaink_num_words
        );
        requestsMapping[requestId] = RequestStatus({
            sender: msg.sender,
            boxId: boxId,
            randomWord: 0,
            randomNumber: 0xfffff,
            timestamp: 0,
            exists: true,
            rewardToken: address(1),
            rewardAmount: 0,
            fulfilled: false,
            claimed: false
        });
        requestIds.push(requestId);
        emit RequestSent(boxId, requestId);
    }

    function getRandomNumber() public view returns (uint256 random) {
        address sender = msg.sender;
        uint256 time = block.timestamp;
        bytes32 randomBytes1 = keccak256(abi.encodePacked(time, sender));
        bytes32 randomBytes2 = randomBytes1 >> 236;
        random = uint256(randomBytes2);
    }

    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] memory _randomWords
    ) internal override{
        require(requestsMapping[_requestId].exists, "request not found");
        emit RequestFulfilled(_requestId, _randomWords[0]);

        RequestStatus storage requestStatus = requestsMapping[_requestId];
        requestStatus.fulfilled = true;
        requestStatus.randomWord = _randomWords[0];
        requestStatus.timestamp = block.timestamp;
        requestStatus.randomNumber = uint256(
            keccak256(
                abi.encodePacked(
                    requestStatus.sender,
                    requestStatus.timestamp,
                    requestStatus.randomWord
                )
            ) >> 236
        );

        MysteryReward memory mysteryReward = mysteryReWardMapping[
            requestStatus.boxId
        ];
        for (uint256 i = 0; i < mysteryReward.rangeArray.length; i++) {
            if (requestStatus.randomNumber < mysteryReward.rangeArray[i]) {
                address token = mysteryReward.tokenArray[i];
                uint256 rewardAmount = mysteryReward.rewardAmountArray[i];
                
                requestStatus.rewardToken = token;
                requestStatus.rewardAmount = rewardAmount;

                uint256 tokenBalance = boxAccount[requestStatus.boxId][token] -
                    rewardAmount;
                boxAccount[requestStatus.boxId][token] = tokenBalance;
                if (tokenBalance < mysteryReward.rewardAmountArray[i]) {
                    Mystery storage mystery = mysteryMapping[
                        requestStatus.boxId
                    ];
                    mystery.frozen = true;
                }
                return;
            }
        }
    }


    function fulfillRandomWordsManual(
        uint256 _requestId
    ) public {
        require(requestsMapping[_requestId].exists, "request not found");
        uint randomWord = getRandomNumber();
        RequestStatus storage requestStatus = requestsMapping[_requestId];
        requestStatus.fulfilled = true;
        requestStatus.randomWord = randomWord;
        requestStatus.timestamp = block.timestamp;
        requestStatus.randomNumber = uint256(
            keccak256(
                abi.encodePacked(
                    requestStatus.sender,
                    requestStatus.timestamp,
                    requestStatus.randomWord
                )
            ) >> 236
        );

        MysteryReward memory mysteryReward = mysteryReWardMapping[
            requestStatus.boxId
        ];
        for (uint256 i = 0; i < mysteryReward.rangeArray.length; i++) {
            if (requestStatus.randomNumber < mysteryReward.rangeArray[i]) {
                address token = mysteryReward.tokenArray[i];
                uint256 rewardAmount = mysteryReward.rewardAmountArray[i];
                
                requestStatus.rewardToken = token;
                requestStatus.rewardAmount = rewardAmount;

                uint256 tokenBalance = boxAccount[requestStatus.boxId][token] -
                    rewardAmount;
                boxAccount[requestStatus.boxId][token] = tokenBalance;
                if (tokenBalance < mysteryReward.rewardAmountArray[i]) {
                    Mystery storage mystery = mysteryMapping[
                        requestStatus.boxId
                    ];
                    mystery.frozen = true;
                }
                return;
            }
        }
    }

    function settingChainlink(uint64 _sub_id,bytes32 _key_hash, uint32 _callback_gas_limit) external{
        chainlink_subscription_id = _sub_id;
        chainlink_key_hash = _key_hash;
        chainlink_callback_gas_limit = _callback_gas_limit;
    }

    uint256 destruct;
    
    function proposalDestruct() external onlyOwner{
        destruct = block.timestamp;
    }

    function deleteContract() external view onlyOwner{
        
        if (destruct != 0 && block.timestamp - destruct > 24 hours){
            //selfdestruct(payable(msg.sender));
        }
        
    }

}
