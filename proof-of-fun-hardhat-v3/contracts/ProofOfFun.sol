// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./EventManager.sol";
import "./EventRewardToken.sol";

/**
 * @title ProofOfFun
 * @dev Anonymous blockchain voting system for event feedback
 * @notice This contract enables anonymous voting on multiple categories while maintaining transparency
 */
contract ProofOfFun is Ownable, ReentrancyGuard, Pausable {
    
    // ============ Structs ============
    
    struct Category {
        string name;
        bool isActive;
        uint256 totalVotes;
        mapping(uint8 => uint256) voteCounts; // rating (1-5) => count
    }
    
    struct Event {
        string name;
        string description;
        uint256 startTime;
        uint256 endTime;
        bool isActive;
        uint256[] categoryIds;
        mapping(uint256 => bool) hasCategory;
        mapping(address => bool) hasVoted;
        mapping(address => mapping(uint256 => bool)) hasVotedCategory;
        uint256 totalParticipants;
    }
    
    struct VoteProof {
        bytes32 voteHash;
        uint256 timestamp;
        uint256 eventId;
        uint256 categoryId;
    }
    
    struct CategoryResult {
        string name;
        uint256 average; // Scaled by 100 (e.g., 425 = 4.25)
        uint256 totalVotes;
        uint256[5] distribution; // Count for each rating 1-5
    }
    
    // ============ State Variables ============
    
    uint256 public nextEventId;
    uint256 public nextCategoryId;
    uint256 public constant MIN_RATING = 1;
    uint256 public constant MAX_RATING = 5;
    uint256 public constant PRECISION = 100; // For average calculation
    
    EventManager public eventManager; // Referencia al contrato de gestión de eventos
    
    mapping(uint256 => Event) public events;
    mapping(uint256 => Category) public categories;
    mapping(bytes32 => VoteProof) public voteProofs;
    mapping(address => uint256) public userVoteCount;
    
    // ============ Events ============
    
    event EventCreated(uint256 indexed eventId, string name, uint256 startTime, uint256 endTime);
    event EventUpdated(uint256 indexed eventId, string name, uint256 startTime, uint256 endTime);
    event EventStatusChanged(uint256 indexed eventId, bool isActive);
    event CategoryCreated(uint256 indexed categoryId, string name);
    event CategoryUpdated(uint256 indexed categoryId, string name);
    event CategoryStatusChanged(uint256 indexed categoryId, bool isActive);
    event VoteCast(uint256 indexed eventId, uint256 indexed categoryId, bytes32 voteHash, uint256 timestamp);
    event VoteRevoked(uint256 indexed eventId, address indexed voter);
    event ResultsPublished(uint256 indexed eventId, uint256 timestamp);
    
    // ============ Errors ============
    
    error InvalidRating();
    error InvalidCategory();
    error InvalidEvent();
    error EventNotActive();
    error EventNotStarted();
    error EventEnded();
    error AlreadyVoted();
    error CategoryNotInEvent();
    error NoVotesRecorded();
    error Unauthorized();
    
    // ============ Constructor ============
    
    constructor() Ownable(msg.sender) {
        // Initialize default categories
        _createCategory("Ambience");
        _createCategory("Organization");
        _createCategory("Content");
        _createCategory("Technology");
        _createCategory("Entertainment");
        _createCategory("Accessibility");
    }

    // ============ Configuration ============
    
    function setEventManager(address _eventManager) external onlyOwner {
        require(_eventManager != address(0), "Invalid address");
        eventManager = EventManager(_eventManager);
    }
    
    // ============ Category Management ============
    
    function _createCategory(string memory _name) internal returns (uint256) {
        uint256 categoryId = nextCategoryId++;
        Category storage category = categories[categoryId];
        category.name = _name;
        category.isActive = true;
        category.totalVotes = 0;
        
        emit CategoryCreated(categoryId, _name);
        return categoryId;
    }
    
    function createCategory(string memory _name) external onlyOwner returns (uint256) {
        return _createCategory(_name);
    }
    
    function updateCategory(uint256 _categoryId, string memory _name) external onlyOwner {
        if (_categoryId >= nextCategoryId) revert InvalidCategory();
        categories[_categoryId].name = _name;
        emit CategoryUpdated(_categoryId, _name);
    }
    
    function toggleCategoryStatus(uint256 _categoryId) external onlyOwner {
        if (_categoryId >= nextCategoryId) revert InvalidCategory();
        categories[_categoryId].isActive = !categories[_categoryId].isActive;
        emit CategoryStatusChanged(_categoryId, categories[_categoryId].isActive);
    }
    
    function getCategory(uint256 _categoryId) external view returns (string memory name, bool isActive, uint256 totalVotes) {
        if (_categoryId >= nextCategoryId) revert InvalidCategory();
        Category storage category = categories[_categoryId];
        return (category.name, category.isActive, category.totalVotes);
    }
    
    function getCategoryVoteDistribution(uint256 _categoryId) external view returns (uint256[5] memory) {
        if (_categoryId >= nextCategoryId) revert InvalidCategory();
        Category storage category = categories[_categoryId];
        uint256[5] memory distribution;
        for (uint8 i = 0; i < 5; i++) {
            distribution[i] = category.voteCounts[i + 1];
        }
        return distribution;
    }
    
    // ============ Event Management ============
    
    function createEvent(
        string memory _name,
        string memory _description,
        uint256 _startTime,
        uint256 _endTime,
        uint256[] memory _categoryIds
    ) external onlyOwner returns (uint256) {
        require(_startTime < _endTime, "Invalid time range");
        require(_categoryIds.length > 0, "No categories provided");
        
        uint256 eventId = nextEventId++;
        Event storage newEvent = events[eventId];
        newEvent.name = _name;
        newEvent.description = _description;
        newEvent.startTime = _startTime;
        newEvent.endTime = _endTime;
        newEvent.isActive = true;
        newEvent.totalParticipants = 0;
        
        // Add categories to event
        for (uint256 i = 0; i < _categoryIds.length; i++) {
            uint256 catId = _categoryIds[i];
            if (catId >= nextCategoryId) revert InvalidCategory();
            if (!categories[catId].isActive) revert InvalidCategory();
            
            newEvent.categoryIds.push(catId);
            newEvent.hasCategory[catId] = true;
        }
        
        emit EventCreated(eventId, _name, _startTime, _endTime);
        return eventId;
    }
    
    function updateEvent(
        uint256 _eventId,
        string memory _name,
        string memory _description,
        uint256 _startTime,
        uint256 _endTime
    ) external onlyOwner {
        if (_eventId >= nextEventId) revert InvalidEvent();
        require(_startTime < _endTime, "Invalid time range");
        
        Event storage eventData = events[_eventId];
        eventData.name = _name;
        eventData.description = _description;
        eventData.startTime = _startTime;
        eventData.endTime = _endTime;
        
        emit EventUpdated(_eventId, _name, _startTime, _endTime);
    }
    
    function toggleEventStatus(uint256 _eventId) external onlyOwner {
        if (_eventId >= nextEventId) revert InvalidEvent();
        events[_eventId].isActive = !events[_eventId].isActive;
        emit EventStatusChanged(_eventId, events[_eventId].isActive);
    }
    
    function getEvent(uint256 _eventId) external view returns (
        string memory name,
        string memory description,
        uint256 startTime,
        uint256 endTime,
        bool isActive,
        uint256 totalParticipants,
        uint256[] memory categoryIds
    ) {
        if (_eventId >= nextEventId) revert InvalidEvent();
        Event storage eventData = events[_eventId];
        return (
            eventData.name,
            eventData.description,
            eventData.startTime,
            eventData.endTime,
            eventData.isActive,
            eventData.totalParticipants,
            eventData.categoryIds
        );
    }
    
    // ============ Voting Functions ============
    
    function vote(
        uint256 _eventId,
        uint256 _categoryId,
        uint8 _rating,
        bytes32 _salt
    ) external nonReentrant whenNotPaused {
        // Validations
        if (_eventId >= nextEventId) revert InvalidEvent();
        if (_categoryId >= nextCategoryId) revert InvalidCategory();
        if (_rating < MIN_RATING || _rating > MAX_RATING) revert InvalidRating();
        
        Event storage eventData = events[_eventId];
        
        if (!eventData.isActive) revert EventNotActive();
        if (block.timestamp < eventData.startTime) revert EventNotStarted();
        if (block.timestamp > eventData.endTime) revert EventEnded();
        if (!eventData.hasCategory[_categoryId]) revert CategoryNotInEvent();
        if (eventData.hasVotedCategory[msg.sender][_categoryId]) revert AlreadyVoted();
        
        // Generate anonymous vote hash
        bytes32 voteHash = keccak256(abi.encodePacked(
            msg.sender,
            _eventId,
            _categoryId,
            _rating,
            _salt,
            block.timestamp
        ));
        
        // Record vote anonymously
        Category storage category = categories[_categoryId];
        category.voteCounts[_rating]++;
        category.totalVotes++;
        
        // Mark as voted
        eventData.hasVotedCategory[msg.sender][_categoryId] = true;
        
        // Track if first vote from user for this event
        if (!eventData.hasVoted[msg.sender]) {
            eventData.hasVoted[msg.sender] = true;
            eventData.totalParticipants++;
        }
        
        // Store vote proof
        VoteProof storage proof = voteProofs[voteHash];
        proof.voteHash = voteHash;
        proof.timestamp = block.timestamp;
        proof.eventId = _eventId;
        proof.categoryId = _categoryId;
        
        userVoteCount[msg.sender]++;
        
        emit VoteCast(_eventId, _categoryId, voteHash, block.timestamp);
    }
    
    function batchVote(
        uint256 _eventId,
        uint256[] memory _categoryIds,
        uint8[] memory _ratings,
        bytes32 _salt
    ) external nonReentrant whenNotPaused {
        require(_categoryIds.length == _ratings.length, "Array length mismatch");
        require(_categoryIds.length > 0, "Empty arrays");
        
        if (_eventId >= nextEventId) revert InvalidEvent();
        
        Event storage eventData = events[_eventId];
        if (!eventData.isActive) revert EventNotActive();
        if (block.timestamp < eventData.startTime) revert EventNotStarted();
        if (block.timestamp > eventData.endTime) revert EventEnded();
        
        for (uint256 i = 0; i < _categoryIds.length; i++) {
            uint256 categoryId = _categoryIds[i];
            uint8 rating = _ratings[i];
            
            if (categoryId >= nextCategoryId) revert InvalidCategory();
            if (rating < MIN_RATING || rating > MAX_RATING) revert InvalidRating();
            if (!eventData.hasCategory[categoryId]) revert CategoryNotInEvent();
            if (eventData.hasVotedCategory[msg.sender][categoryId]) revert AlreadyVoted();
            
            // Generate anonymous vote hash
            bytes32 voteHash = keccak256(abi.encodePacked(
                msg.sender,
                _eventId,
                categoryId,
                rating,
                _salt,
                block.timestamp,
                i // Include index for uniqueness
            ));
            
            // Record vote anonymously
            Category storage category = categories[categoryId];
            category.voteCounts[rating]++;
            category.totalVotes++;
            
            // Mark as voted
            eventData.hasVotedCategory[msg.sender][categoryId] = true;
            
            // Store vote proof
            VoteProof storage proof = voteProofs[voteHash];
            proof.voteHash = voteHash;
            proof.timestamp = block.timestamp;
            proof.eventId = _eventId;
            proof.categoryId = categoryId;
            
            emit VoteCast(_eventId, categoryId, voteHash, block.timestamp);
        }
        
        // Track participant (only once per event)
        if (!eventData.hasVoted[msg.sender]) {
            eventData.hasVoted[msg.sender] = true;
            eventData.totalParticipants++;
        }
        
        userVoteCount[msg.sender] += _categoryIds.length;

        // Verificar si el usuario completó todas las categorías del evento
        // y otorgar tokens de recompensa por completar la encuesta
        bool hasCompletedSurvey = true;
        for (uint256 i = 0; i < eventData.categoryIds.length; i++) {
            if (!eventData.hasVotedCategory[msg.sender][eventData.categoryIds[i]]) {
                hasCompletedSurvey = false;
                break;
            }
        }

        if (hasCompletedSurvey && address(eventManager) != address(0)) {
            try eventManager.events(_eventId) returns (
                uint256,
                string memory,
                string memory,
                string memory,
                string memory,
                address,
                uint256,
                uint256,
                uint256,
                uint256,
                EventManager.EventStatus,
                uint256,
                uint256,
                uint256,
                bool,
                bytes32,
                address rewardToken
            ) {
                if (rewardToken != address(0)) {
                    EventRewardToken(rewardToken).rewardSurvey(msg.sender);
                }
            } catch {}
        }
    }
    
    // ============ Results Calculation ============
    
    function calculateCategoryAverage(uint256 _categoryId) public view returns (uint256) {
        if (_categoryId >= nextCategoryId) revert InvalidCategory();
        
        Category storage category = categories[_categoryId];
        if (category.totalVotes == 0) revert NoVotesRecorded();
        
        uint256 weightedSum = 0;
        for (uint8 rating = 1; rating <= MAX_RATING; rating++) {
            weightedSum += category.voteCounts[rating] * rating;
        }
        
        // Return average scaled by PRECISION (e.g., 425 = 4.25)
        return (weightedSum * PRECISION) / category.totalVotes;
    }
    
    function getEventResults(uint256 _eventId) external view returns (CategoryResult[] memory) {
        if (_eventId >= nextEventId) revert InvalidEvent();
        
        Event storage eventData = events[_eventId];
        uint256 categoryCount = eventData.categoryIds.length;
        CategoryResult[] memory results = new CategoryResult[](categoryCount);
        
        for (uint256 i = 0; i < categoryCount; i++) {
            uint256 catId = eventData.categoryIds[i];
            Category storage category = categories[catId];
            
            results[i].name = category.name;
            results[i].totalVotes = category.totalVotes;
            
            if (category.totalVotes > 0) {
                results[i].average = calculateCategoryAverage(catId);
                
                // Get distribution
                for (uint8 rating = 1; rating <= MAX_RATING; rating++) {
                    results[i].distribution[rating - 1] = category.voteCounts[rating];
                }
            }
        }
        
        return results;
    }
    
    function publishResults(uint256 _eventId) external onlyOwner {
        if (_eventId >= nextEventId) revert InvalidEvent();
        Event storage eventData = events[_eventId];
        
        require(block.timestamp > eventData.endTime, "Event not ended");
        
        emit ResultsPublished(_eventId, block.timestamp);
    }
    
    // ============ Query Functions ============
    
    function hasUserVoted(uint256 _eventId, address _user) external view returns (bool) {
        if (_eventId >= nextEventId) revert InvalidEvent();
        return events[_eventId].hasVoted[_user];
    }
    
    function hasUserVotedCategory(uint256 _eventId, address _user, uint256 _categoryId) external view returns (bool) {
        if (_eventId >= nextEventId) revert InvalidEvent();
        if (_categoryId >= nextCategoryId) revert InvalidCategory();
        return events[_eventId].hasVotedCategory[_user][_categoryId];
    }
    
    function getActiveCategories() external view returns (uint256[] memory) {
        uint256 activeCount = 0;
        
        // Count active categories
        for (uint256 i = 0; i < nextCategoryId; i++) {
            if (categories[i].isActive) {
                activeCount++;
            }
        }
        
        // Build array of active category IDs
        uint256[] memory activeCategories = new uint256[](activeCount);
        uint256 index = 0;
        for (uint256 i = 0; i < nextCategoryId; i++) {
            if (categories[i].isActive) {
                activeCategories[index] = i;
                index++;
            }
        }
        
        return activeCategories;
    }
    
    function getActiveEvents() external view returns (uint256[] memory) {
        uint256 activeCount = 0;
        
        // Count active events
        for (uint256 i = 0; i < nextEventId; i++) {
            if (events[i].isActive) {
                activeCount++;
            }
        }
        
        // Build array of active event IDs
        uint256[] memory activeEvents = new uint256[](activeCount);
        uint256 index = 0;
        for (uint256 i = 0; i < nextEventId; i++) {
            if (events[i].isActive) {
                activeEvents[index] = i;
                index++;
            }
        }
        
        return activeEvents;
    }
    
    // ============ Admin Functions ============
    
    function pause() external onlyOwner {
        _pause();
    }
    
    function unpause() external onlyOwner {
        _unpause();
    }
    
    function getCategoryCount() external view returns (uint256) {
        return nextCategoryId;
    }
    
    function getEventCount() external view returns (uint256) {
        return nextEventId;
    }
}
