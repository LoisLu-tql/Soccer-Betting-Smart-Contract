// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

contract SoccerBetting {

    enum MatchStatus { NOT_START, RUNNING, END_WIN, END_LOSE, END_DRAW }

    enum Ending { WIN, LOSE, DRAW }

    struct BetInfo {
        uint256 betId;
        uint256 totalAmount;
        uint256 rightAmount;    // The amount that bet on the right outcome
        string homeTeam;
        string awayTeam;
        string startTime;
        MatchStatus status;
        bool isActive;
    }

    struct Bet {
        uint256 betId;
        uint256 betAmount;
        address betUser;
        Ending prediction;
        bool isReward;  // the reward is collected or not
    }

    uint256 private betIdCounter = 0;
    uint256 private activeCounter = 0;

    mapping (address => bool) isAdmin;          // user address => whether he is an admin
    mapping (uint256 => BetInfo) betInfoList;   // bet id => bet info
    mapping (uint256 => Bet[]) betList;         // bet id => all bets on this
    mapping (address => Bet[]) betHistory;      // user address => the bets he made


    constructor() {
        isAdmin[msg.sender] = true;     // contract owner is the admin
    }

    modifier checkAuthority {
        require(isAdmin[msg.sender], "You are not authorized.");
        _;
    }

    modifier checkValidBetId (uint256 betId) {
        require(betId >= 0 && betId <betIdCounter, "Please input a valid bet Id.");
        _;
    }

    function placeBetInfo(string memory homeTeam, string memory awayTeam, string memory startTime) public checkAuthority {
        require(bytes(homeTeam).length != 0 && bytes(awayTeam).length != 0 && bytes(startTime).length != 0, "Input should not be empty string.");
        BetInfo memory betInfo = BetInfo(betIdCounter, 0, 0, homeTeam, awayTeam, startTime, MatchStatus.NOT_START, true);
        betInfoList[betIdCounter] = betInfo;
        betIdCounter++;
        activeCounter++;
    }

    function updateBetInfo(uint256 betId, MatchStatus status) public checkAuthority checkValidBetId(betId) {
        require(status > betInfoList[betId].status, "You cannot reverse the status.");
        require(uint(status) < 2, "You cannot change the match outcome.");
        betInfoList[betId].status = status;
        if(betInfoList[betId].isActive) {
            betInfoList[betId].isActive = false;
            activeCounter--;
        }
        if(uint(status) > 1) {
            for(uint i=0; i<betList[betId].length; i++) {
                if(uint(betList[betId][i].prediction) + 2 == uint(betInfoList[betId].status)) {
                    betInfoList[betId].rightAmount += betList[betId][i].betAmount;
                }
            }
        }
    }

    function queryActiveBetNowAll() public view returns (BetInfo[] memory) {
        BetInfo[] memory activeList = new BetInfo[](activeCounter);
        uint256 count = 0;
        for(uint i=0; i<betIdCounter; i++) {
            if(betInfoList[i].isActive) {
                activeList[count] = betInfoList[i];
                count++;
            }
        }
        return activeList;
    }

    function queryActiveBetNowByTeam(string memory team) public view returns (BetInfo[] memory) {
        require(bytes(team).length != 0, "Input team should not be empty string.");
        uint outcomeCount = 0;
        for(uint i=0; i<betIdCounter; i++) {
            if(keccak256(abi.encodePacked(betInfoList[i].homeTeam)) == keccak256(abi.encodePacked(team)) || 
                keccak256(abi.encodePacked(betInfoList[i].awayTeam)) == keccak256(abi.encodePacked(team))) {
                outcomeCount++;
            }
        }
        BetInfo[] memory outcomeList = new BetInfo[](outcomeCount);
        uint256 count = 0;
        for(uint i=0; i<betIdCounter; i++) {
            if(keccak256(abi.encodePacked(betInfoList[i].homeTeam)) == keccak256(abi.encodePacked(team)) || 
                keccak256(abi.encodePacked(betInfoList[i].awayTeam)) == keccak256(abi.encodePacked(team))) {
                outcomeList[count] = betInfoList[i];
                count++;
            }
        }
        return outcomeList;
    }

    function checkBetDetail(uint256 betId) public view checkValidBetId(betId) returns (BetInfo memory) {
        return betInfoList[betId];
    }

    
    function betOnIt(uint256 betId, uint256 betAmount, Ending prediction) public payable checkValidBetId(betId) {
        require(betAmount > 0, "You should enter positive amount.");
        require(msg.value == betAmount, "You should pay the right amount.");
        Bet memory newBet = Bet(betId, betAmount, msg.sender, prediction, false);
        betInfoList[betId].totalAmount += betAmount;
        betList[betId].push(newBet);
        betHistory[msg.sender].push(newBet);
    }

    // msg sender collect the reward for correct prediction
    function getReward(uint256 betId) public checkValidBetId(betId) {
        require(uint(betInfoList[betId].status) > 1, "The match has not finished yet.");
        for(uint i=0; i<betList[betId].length; i++) {
            if(betList[betId][i].betUser == msg.sender && !betList[betId][i].isReward &&
                uint(betList[betId][i].prediction) + 2 == uint(betInfoList[betId].status)) {
                    payable(msg.sender).transfer(
                        betList[betId][i].betAmount / betInfoList[betId].rightAmount * betInfoList[betId].totalAmount);
                    betList[betId][i].isReward = true;
                } 
        }
    }

    // get the bet history of the msg sender
    function getMyBetHistory() public view returns (Bet[] memory) {
        return betHistory[msg.sender];
    }
}