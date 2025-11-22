// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IProofOfFun
 * @dev Interface for the ProofOfFun contract
 */
interface IProofOfFun {
    struct CategoryResult {
        string name;
        uint256 average;
        uint256 totalVotes;
        uint256[5] distribution;
    }
    
    function vote(uint256 _eventId, uint256 _categoryId, uint8 _rating, bytes32 _salt) external;
    function batchVote(uint256 _eventId, uint256[] memory _categoryIds, uint8[] memory _ratings, bytes32 _salt) external;
    function getEventResults(uint256 _eventId) external view returns (CategoryResult[] memory);
    function calculateCategoryAverage(uint256 _categoryId) external view returns (uint256);
}

/**
 * @title IEventManager
 * @dev Interface for the EventManager contract
 */
interface IEventManager {
    enum EventStatus { Created, Active, VotingOpen, VotingClosed, Completed, Cancelled }
    
    struct EventDetails {
        uint256 id;
        string name;
        string description;
        string location;
        string imageUrl;
        address organizer;
        uint256 startTime;
        uint256 endTime;
        uint256 votingStartTime;
        uint256 votingEndTime;
        EventStatus status;
        uint256 maxParticipants;
        uint256 currentParticipants;
        uint256 totalVotes;
        bool requiresRegistration;
        bytes32 eventHash;
    }
    
    function createEvent(
        string memory _name,
        string memory _description,
        string memory _location,
        string memory _imageUrl,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _votingStartTime,
        uint256 _votingEndTime,
        uint256 _maxParticipants,
        bool _requiresRegistration
    ) external returns (uint256);
    
    function getEvent(uint256 _eventId) external view returns (EventDetails memory);
    function registerForEvent(uint256 _eventId) external;
    function canVote(uint256 _eventId, address _participant) external view returns (bool);
}

/**
 * @title IAnonymousVoteToken
 * @dev Interface for the AnonymousVoteToken contract
 */
interface IAnonymousVoteToken {
    struct VoteMetadata {
        uint256 eventId;
        uint256 categoryId;
        uint256 timestamp;
        bytes32 voteCommitment;
        bool isRevealed;
    }
    
    function mintVoteToken(
        address _to,
        uint256 _eventId,
        uint256 _categoryId,
        bytes32 _voteCommitment
    ) external returns (uint256);
    
    function batchMintVoteTokens(
        address _to,
        uint256 _eventId,
        uint256[] memory _categoryIds,
        bytes32[] memory _voteCommitments
    ) external returns (uint256[] memory);
    
    function getUserTokens(address _user) external view returns (uint256[] memory);
}
