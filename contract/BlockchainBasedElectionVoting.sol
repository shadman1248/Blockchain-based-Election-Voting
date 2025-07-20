// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Election {
    address public admin;
    bool public electionEnded;
    uint public electionStartTime;
    uint public electionEndTime;
    uint public totalVotes;
    string public electionTitle;
    string public electionDescription;
    
    struct Candidate {
        uint id;
        string name;
        string description;
        uint voteCount;
        bool isActive;
    }
    
    struct Voter {
        bool isRegistered;
        bool hasVoted;
        uint votedFor;
        uint voteTimestamp;
    }
    
    mapping(uint => Candidate) public candidates;
    uint public candidatesCount;
    mapping(address => Voter) public voters;
    
    // New: Whitelist for authorized voters
    mapping(address => bool) public authorizedVoters;
    bool public requireVoterAuthorization;
    
    // Events for better tracking
    event CandidateAdded(uint indexed candidateId, string name);
    event VoteCast(address indexed voter, uint indexed candidateId, uint timestamp);
    event ElectionStarted(uint startTime);
    event ElectionEnded(uint endTime, uint totalVotes);
    event VoterAuthorized(address indexed voter);
    event CandidateDeactivated(uint indexed candidateId);
    
    constructor(
        string memory _title,
        string memory _description,
        bool _requireAuthorization
    ) {
        admin = msg.sender;
        electionEnded = false;
        electionTitle = _title;
        electionDescription = _description;
        requireVoterAuthorization = _requireAuthorization;
        electionStartTime = block.timestamp;
    }
    
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }
    
    modifier electionActive() {
        require(!electionEnded, "Election has ended");
        require(
            electionEndTime == 0 || block.timestamp <= electionEndTime,
            "Election time has expired"
        );
        _;
    }
    
    modifier onlyRegisteredVoter() {
        if (requireVoterAuthorization) {
            require(authorizedVoters[msg.sender], "Voter not authorized");
        }
        _;
    }
    
    // ✅ NEW: Set election duration
    function setElectionDuration(uint _durationInHours) public onlyAdmin {
        require(!electionEnded, "Cannot modify ended election");
        electionEndTime = block.timestamp + (_durationInHours * 1 hours);
    }
    
    // ✅ NEW: Authorize voters (for private elections)
    function authorizeVoter(address _voter) public onlyAdmin {
        authorizedVoters[_voter] = true;
        emit VoterAuthorized(_voter);
    }
    
    // ✅ NEW: Authorize multiple voters at once
    function authorizeVoters(address[] memory _voters) public onlyAdmin {
        for (uint i = 0; i < _voters.length; i++) {
            authorizedVoters[_voters[i]] = true;
            emit VoterAuthorized(_voters[i]);
        }
    }
    
    // Enhanced: Add candidate with description
    function addCandidate(string memory _name, string memory _description) public onlyAdmin {
        require(!electionEnded, "Cannot add candidates to ended election");
        candidatesCount++;
        candidates[candidatesCount] = Candidate(
            candidatesCount,
            _name,
            _description,
            0,
            true
        );
        emit CandidateAdded(candidatesCount, _name);
    }
    
    // ✅ NEW: Deactivate a candidate (in case of withdrawal)
    function deactivateCandidate(uint _candidateId) public onlyAdmin {
        require(_candidateId > 0 && _candidateId <= candidatesCount, "Invalid candidate");
        candidates[_candidateId].isActive = false;
        emit CandidateDeactivated(_candidateId);
    }
    
    // Enhanced voting function
    function vote(uint _candidateId) public electionActive onlyRegisteredVoter {
        require(!voters[msg.sender].hasVoted, "You have already voted");
        require(_candidateId > 0 && _candidateId <= candidatesCount, "Invalid candidate");
        require(candidates[_candidateId].isActive, "Candidate is not active");
        
        candidates[_candidateId].voteCount++;
        voters[msg.sender] = Voter(true, true, _candidateId, block.timestamp);
        totalVotes++;
        
        emit VoteCast(msg.sender, _candidateId, block.timestamp);
    }
    
    // ✅ NEW: Emergency vote removal (only by admin, with strong restrictions)
    function removeVote(address _voter) public onlyAdmin {
        require(voters[_voter].hasVoted, "Voter has not voted");
        require(!electionEnded, "Cannot modify votes after election ends");
        
        uint candidateId = voters[_voter].votedFor;
        candidates[candidateId].voteCount--;
        voters[_voter].hasVoted = false;
        voters[_voter].votedFor = 0;
        totalVotes--;
    }
    
    function endElection() public onlyAdmin {
        electionEnded = true;
        emit ElectionEnded(block.timestamp, totalVotes);
    }
    
    // ✅ NEW: Auto-end election if time expires
    function checkAndEndElection() public {
        require(electionEndTime > 0, "No end time set");
        require(block.timestamp > electionEndTime, "Election time not yet expired");
        require(!electionEnded, "Election already ended");
        
        electionEnded = true;
        emit ElectionEnded(block.timestamp, totalVotes);
    }
    
    // Enhanced: Return all active candidates only
    function getAllCandidates() public view returns (Candidate[] memory) {
        // Count active candidates
        uint activeCount = 0;
        for (uint i = 1; i <= candidatesCount; i++) {
            if (candidates[i].isActive) {
                activeCount++;
            }
        }
        
        Candidate[] memory result = new Candidate[](activeCount);
        uint index = 0;
        for (uint i = 1; i <= candidatesCount; i++) {
            if (candidates[i].isActive) {
                result[index] = candidates[i];
                index++;
            }
        }
        return result;
    }
    
    // Enhanced: Get winners with vote counts
    function getWinners() public view returns (uint[] memory winnerIds, uint winningVotes) {
        require(electionEnded, "Election is not yet ended");
        
        uint highestVotes = 0;
        uint winnerCount = 0;
        
        // First pass: Find highest vote count among active candidates
        for (uint i = 1; i <= candidatesCount; i++) {
            if (candidates[i].isActive && candidates[i].voteCount > highestVotes) {
                highestVotes = candidates[i].voteCount;
            }
        }
        
        // Count winners
        for (uint i = 1; i <= candidatesCount; i++) {
            if (candidates[i].isActive && candidates[i].voteCount == highestVotes) {
                winnerCount++;
            }
        }
        
        // Store all winners
        uint[] memory winners = new uint[](winnerCount);
        uint index = 0;
        for (uint i = 1; i <= candidatesCount; i++) {
            if (candidates[i].isActive && candidates[i].voteCount == highestVotes) {
                winners[index++] = i;
            }
        }
        
        return (winners, highestVotes);
    }
    
    function hasUserVoted(address _voter) public view returns (bool) {
        return voters[_voter].hasVoted;
    }
    
    // Enhanced: Get comprehensive candidate details
    function getCandidate(uint _id) public view returns (
        uint id,
        string memory name,
        string memory description,
        uint voteCount,
        bool isActive
    ) {
        require(_id > 0 && _id <= candidatesCount, "Invalid candidate ID");
        Candidate memory c = candidates[_id];
        return (c.id, c.name, c.description, c.voteCount, c.isActive);
    }
    
    // ✅ NEW: Get voter details
    function getVoterInfo(address _voter) public view returns (
        bool isRegistered,
        bool hasVoted,
        uint votedFor,
        uint voteTimestamp
    ) {
        Voter memory v = voters[_voter];
        return (v.isRegistered, v.hasVoted, v.votedFor, v.voteTimestamp);
    }
    
    // ✅ NEW: Get election statistics
    function getElectionStats() public view returns (
        uint totalCandidates,
        uint activeCandidates,
        uint totalVotesCast,
        uint electionDuration,
        bool isActive
    ) {
        uint active = 0;
        for (uint i = 1; i <= candidatesCount; i++) {
            if (candidates[i].isActive) {
                active++;
            }
        }
        
        uint duration = 0;
        if (electionEndTime > electionStartTime) {
            duration = electionEndTime - electionStartTime;
        }
        
        bool active_status = !electionEnded && 
                           (electionEndTime == 0 || block.timestamp <= electionEndTime);
        
        return (candidatesCount, active, totalVotes, duration, active_status);
    }
    
    // ✅ NEW: Get time remaining
    function getTimeRemaining() public view returns (uint secondsRemaining) {
        if (electionEnded || electionEndTime == 0) {
            return 0;
        }
        
        if (block.timestamp >= electionEndTime) {
            return 0;
        }
        
        return electionEndTime - block.timestamp;
    }
    
    // ✅ NEW: Transfer admin rights
    function transferAdmin(address _newAdmin) public onlyAdmin {
        require(_newAdmin != address(0), "Invalid address");
        admin = _newAdmin;
    }
    
    // ✅ NEW: Get election metadata
    function getElectionInfo() public view returns (
        string memory title,
        string memory description,
        address adminAddress,
        uint startTime,
        uint endTime,
        bool ended
    ) {
        return (
            electionTitle,
            electionDescription,
            admin,
            electionStartTime,
            electionEndTime,
            electionEnded
        );
    }
}
