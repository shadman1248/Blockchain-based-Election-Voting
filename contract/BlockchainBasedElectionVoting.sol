// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Election {
    address public admin;
    bool public electionEnded;

    struct Candidate {
        uint id;
        string name;
        uint voteCount;
    }

    mapping(uint => Candidate) public candidates;
    uint public candidatesCount;

    mapping(address => bool) public hasVoted;

    constructor() {
        admin = msg.sender;
        electionEnded = false;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }

    modifier electionActive() {
        require(!electionEnded, "Election has ended");
        _;
    }

    function addCandidate(string memory _name) public onlyAdmin {
        candidatesCount++;
        candidates[candidatesCount] = Candidate(candidatesCount, _name, 0);
    }

    function vote(uint _candidateId) public electionActive {
        require(!hasVoted[msg.sender], "You have already voted");
        require(_candidateId > 0 && _candidateId <= candidatesCount, "Invalid candidate");

        candidates[_candidateId].voteCount++;
        hasVoted[msg.sender] = true;
    }

    function endElection() public onlyAdmin {
        electionEnded = true;
    }

    // ✅ New: Return all candidates
    function getAllCandidates() public view returns (Candidate[] memory) {
        Candidate[] memory result = new Candidate[](candidatesCount);
        for (uint i = 1; i <= candidatesCount; i++) {
            result[i - 1] = candidates[i];
        }
        return result;
    }

    // ✅ New: Return the winner(s)
    function getWinners() public view returns (uint[] memory) {
        require(electionEnded, "Election is not yet ended");

        uint highestVotes = 0;
        uint winnerCount = 0;

        // First pass: Find highest vote count
        for (uint i = 1; i <= candidatesCount; i++) {
            if (candidates[i].voteCount > highestVotes) {
                highestVotes = candidates[i].voteCount;
            }
        }

        // Count how many candidates have that vote count
        for (uint i = 1; i <= candidatesCount; i++) {
            if (candidates[i].voteCount == highestVotes) {
                winnerCount++;
            }
        }

        // Store all winners
        uint[] memory winners = new uint[](winnerCount);
        uint index = 0;
        for (uint i = 1; i <= candidatesCount; i++) {
            if (candidates[i].voteCount == highestVotes) {
                winners[index++] = i;
            }
        }

        return winners;
    }

    // ✅ New: Check if a voter has voted
    function hasUserVoted(address _voter) public view returns (bool) {
        return hasVoted[_voter];
    }

    // ✅ New: Get candidate details
    function getCandidate(uint _id) public view returns (uint, string memory, uint) {
        require(_id > 0 && _id <= candidatesCount, "Invalid candidate ID");
        Candidate memory c = candidates[_id];
        return (c.id, c.name, c.voteCount);
    }
}
