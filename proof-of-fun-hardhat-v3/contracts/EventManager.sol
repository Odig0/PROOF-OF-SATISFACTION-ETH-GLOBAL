// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title EventManager
 * @dev Manages event creation, updates, and lifecycle for the Proof of Fun voting system
 */
contract EventManager is AccessControl, ReentrancyGuard, Pausable {
    
    bytes32 public constant ORGANIZER_ROLE = keccak256("ORGANIZER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    
    // ============ Structs ============
    
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
    
    enum EventStatus {
        Created,
        Active,
        VotingOpen,
        VotingClosed,
        Completed,
        Cancelled
    }
    
    struct EventStatistics {
        uint256 totalParticipants;
        uint256 totalVotes;
        uint256 uniqueVoters;
        uint256 averageRating;
        uint256 completionRate;
    }
    
    // ============ State Variables ============
    
    uint256 public nextEventId;
    mapping(uint256 => EventDetails) public events;
    mapping(uint256 => mapping(address => bool)) public eventRegistrations;
    mapping(uint256 => mapping(address => bool)) public eventAttendance;
    mapping(uint256 => EventStatistics) public eventStatistics;
    mapping(address => uint256[]) public organizerEvents;
    mapping(address => uint256[]) public participantEvents;
    
    uint256 public constant MIN_EVENT_DURATION = 1 hours;
    uint256 public constant MAX_EVENT_DURATION = 30 days;
    uint256 public constant MIN_VOTING_DURATION = 1 hours;
    
    // ============ Events ============
    
    event EventCreated(
        uint256 indexed eventId,
        string name,
        address indexed organizer,
        uint256 startTime,
        uint256 endTime
    );
    
    event EventUpdated(uint256 indexed eventId, string name);
    event EventStatusChanged(uint256 indexed eventId, EventStatus status);
    event ParticipantRegistered(uint256 indexed eventId, address indexed participant);
    event ParticipantUnregistered(uint256 indexed eventId, address indexed participant);
    event AttendanceMarked(uint256 indexed eventId, address indexed participant);
    event VotingStarted(uint256 indexed eventId, uint256 votingEndTime);
    event VotingEnded(uint256 indexed eventId, uint256 totalVotes);
    event EventCompleted(uint256 indexed eventId, uint256 totalParticipants, uint256 totalVotes);
    event EventCancelled(uint256 indexed eventId, string reason);
    
    // ============ Errors ============
    
    error InvalidEventId();
    error InvalidTimeRange();
    error InvalidVotingPeriod();
    error EventNotActive();
    error EventFull();
    error AlreadyRegistered();
    error NotRegistered();
    error RegistrationNotRequired();
    error Unauthorized();
    error InvalidStatus();
    error EventNotEnded();
    
    // ============ Constructor ============
    
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(ORGANIZER_ROLE, msg.sender);
    }
    
    // ============ Modifiers ============
    
    modifier onlyEventOrganizer(uint256 _eventId) {
        if (_eventId >= nextEventId) revert InvalidEventId();
        require(
            events[_eventId].organizer == msg.sender || hasRole(ADMIN_ROLE, msg.sender),
            "Not event organizer"
        );
        _;
    }
    
    modifier validEvent(uint256 _eventId) {
        if (_eventId >= nextEventId) revert InvalidEventId();
        _;
    }
    
    // ============ Event Creation & Management ============
    
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
    ) external onlyRole(ORGANIZER_ROLE) whenNotPaused returns (uint256) {
        // Validate times
        require(_startTime > block.timestamp, "Start time must be in future");
        require(_endTime > _startTime, "End time must be after start time");
        require(_endTime - _startTime >= MIN_EVENT_DURATION, "Event too short");
        require(_endTime - _startTime <= MAX_EVENT_DURATION, "Event too long");
        
        require(_votingStartTime >= _startTime, "Voting must start during or after event");
        require(_votingEndTime > _votingStartTime, "Invalid voting period");
        require(_votingEndTime - _votingStartTime >= MIN_VOTING_DURATION, "Voting period too short");
        
        require(_maxParticipants > 0, "Max participants must be greater than 0");
        require(bytes(_name).length > 0, "Name cannot be empty");
        
        uint256 eventId = nextEventId++;
        
        bytes32 eventHash = keccak256(abi.encodePacked(
            eventId,
            _name,
            msg.sender,
            _startTime,
            block.timestamp
        ));
        
        events[eventId] = EventDetails({
            id: eventId,
            name: _name,
            description: _description,
            location: _location,
            imageUrl: _imageUrl,
            organizer: msg.sender,
            startTime: _startTime,
            endTime: _endTime,
            votingStartTime: _votingStartTime,
            votingEndTime: _votingEndTime,
            status: EventStatus.Created,
            maxParticipants: _maxParticipants,
            currentParticipants: 0,
            totalVotes: 0,
            requiresRegistration: _requiresRegistration,
            eventHash: eventHash
        });
        
        organizerEvents[msg.sender].push(eventId);
        
        emit EventCreated(eventId, _name, msg.sender, _startTime, _endTime);
        
        return eventId;
    }
    
    function updateEvent(
        uint256 _eventId,
        string memory _name,
        string memory _description,
        string memory _location,
        string memory _imageUrl
    ) external onlyEventOrganizer(_eventId) {
        EventDetails storage eventData = events[_eventId];
        require(eventData.status == EventStatus.Created, "Can only update created events");
        require(bytes(_name).length > 0, "Name cannot be empty");
        
        eventData.name = _name;
        eventData.description = _description;
        eventData.location = _location;
        eventData.imageUrl = _imageUrl;
        
        emit EventUpdated(_eventId, _name);
    }
    
    function updateEventTimes(
        uint256 _eventId,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _votingStartTime,
        uint256 _votingEndTime
    ) external onlyEventOrganizer(_eventId) {
        EventDetails storage eventData = events[_eventId];
        require(eventData.status == EventStatus.Created, "Can only update created events");
        
        require(_startTime > block.timestamp, "Start time must be in future");
        require(_endTime > _startTime, "End time must be after start time");
        require(_votingStartTime >= _startTime, "Voting must start during or after event");
        require(_votingEndTime > _votingStartTime, "Invalid voting period");
        
        eventData.startTime = _startTime;
        eventData.endTime = _endTime;
        eventData.votingStartTime = _votingStartTime;
        eventData.votingEndTime = _votingEndTime;
        
        emit EventUpdated(_eventId, eventData.name);
    }
    
    // ============ Event Status Management ============
    
    function activateEvent(uint256 _eventId) external onlyEventOrganizer(_eventId) {
        EventDetails storage eventData = events[_eventId];
        require(eventData.status == EventStatus.Created, "Event already activated");
        require(block.timestamp >= eventData.startTime, "Event not started yet");
        
        eventData.status = EventStatus.Active;
        emit EventStatusChanged(_eventId, EventStatus.Active);
    }
    
    function startVoting(uint256 _eventId) external onlyEventOrganizer(_eventId) {
        EventDetails storage eventData = events[_eventId];
        require(eventData.status == EventStatus.Active, "Event must be active");
        require(block.timestamp >= eventData.votingStartTime, "Voting period not started");
        require(block.timestamp < eventData.votingEndTime, "Voting period ended");
        
        eventData.status = EventStatus.VotingOpen;
        emit VotingStarted(_eventId, eventData.votingEndTime);
    }
    
    function endVoting(uint256 _eventId) external onlyEventOrganizer(_eventId) {
        EventDetails storage eventData = events[_eventId];
        require(eventData.status == EventStatus.VotingOpen, "Voting not open");
        require(
            block.timestamp >= eventData.votingEndTime || hasRole(ADMIN_ROLE, msg.sender),
            "Voting period not ended"
        );
        
        eventData.status = EventStatus.VotingClosed;
        emit VotingEnded(_eventId, eventData.totalVotes);
    }
    
    function completeEvent(uint256 _eventId) external onlyEventOrganizer(_eventId) {
        EventDetails storage eventData = events[_eventId];
        require(eventData.status == EventStatus.VotingClosed, "Voting must be closed");
        
        eventData.status = EventStatus.Completed;
        emit EventCompleted(_eventId, eventData.currentParticipants, eventData.totalVotes);
    }
    
    function cancelEvent(uint256 _eventId, string memory _reason) external onlyEventOrganizer(_eventId) {
        EventDetails storage eventData = events[_eventId];
        require(
            eventData.status == EventStatus.Created || eventData.status == EventStatus.Active,
            "Cannot cancel event in this status"
        );
        
        eventData.status = EventStatus.Cancelled;
        emit EventCancelled(_eventId, _reason);
    }
    
    // ============ Registration & Attendance ============
    
    function registerForEvent(uint256 _eventId) external validEvent(_eventId) whenNotPaused {
        EventDetails storage eventData = events[_eventId];
        
        require(eventData.requiresRegistration, "Registration not required");
        require(eventData.status == EventStatus.Created || eventData.status == EventStatus.Active, "Event not accepting registrations");
        require(block.timestamp < eventData.startTime, "Event already started");
        require(eventData.currentParticipants < eventData.maxParticipants, "Event is full");
        require(!eventRegistrations[_eventId][msg.sender], "Already registered");
        
        eventRegistrations[_eventId][msg.sender] = true;
        eventData.currentParticipants++;
        participantEvents[msg.sender].push(_eventId);
        
        emit ParticipantRegistered(_eventId, msg.sender);
    }
    
    function unregisterFromEvent(uint256 _eventId) external validEvent(_eventId) {
        EventDetails storage eventData = events[_eventId];
        
        require(eventData.requiresRegistration, "Registration not required");
        require(eventData.status == EventStatus.Created, "Cannot unregister from active event");
        require(eventRegistrations[_eventId][msg.sender], "Not registered");
        require(block.timestamp < eventData.startTime, "Event already started");
        
        eventRegistrations[_eventId][msg.sender] = false;
        eventData.currentParticipants--;
        
        emit ParticipantUnregistered(_eventId, msg.sender);
    }
    
    function markAttendance(uint256 _eventId, address _participant) 
        external 
        onlyEventOrganizer(_eventId) 
        validEvent(_eventId) 
    {
        EventDetails storage eventData = events[_eventId];
        require(eventData.status == EventStatus.Active, "Event not active");
        
        if (eventData.requiresRegistration) {
            require(eventRegistrations[_eventId][_participant], "Participant not registered");
        }
        
        require(!eventAttendance[_eventId][_participant], "Attendance already marked");
        
        eventAttendance[_eventId][_participant] = true;
        
        // Add to participant events if not already registered
        if (!eventData.requiresRegistration) {
            bool alreadyAdded = false;
            uint256[] memory userEvents = participantEvents[_participant];
            for (uint256 i = 0; i < userEvents.length; i++) {
                if (userEvents[i] == _eventId) {
                    alreadyAdded = true;
                    break;
                }
            }
            if (!alreadyAdded) {
                participantEvents[_participant].push(_eventId);
            }
        }
        
        emit AttendanceMarked(_eventId, _participant);
    }
    
    function batchMarkAttendance(uint256 _eventId, address[] memory _participants) 
        external 
        onlyEventOrganizer(_eventId) 
        validEvent(_eventId) 
    {
        EventDetails storage eventData = events[_eventId];
        require(eventData.status == EventStatus.Active, "Event not active");
        
        for (uint256 i = 0; i < _participants.length; i++) {
            address participant = _participants[i];
            
            if (eventData.requiresRegistration && !eventRegistrations[_eventId][participant]) {
                continue;
            }
            
            if (eventAttendance[_eventId][participant]) {
                continue;
            }
            
            eventAttendance[_eventId][participant] = true;
            
            if (!eventData.requiresRegistration) {
                participantEvents[participant].push(_eventId);
            }
            
            emit AttendanceMarked(_eventId, participant);
        }
    }
    
    // ============ Vote Tracking ============
    
    function recordVote(uint256 _eventId) external validEvent(_eventId) {
        EventDetails storage eventData = events[_eventId];
        require(eventData.status == EventStatus.VotingOpen, "Voting not open");
        
        eventData.totalVotes++;
        
        EventStatistics storage stats = eventStatistics[_eventId];
        stats.totalVotes++;
    }
    
    function updateStatistics(
        uint256 _eventId,
        uint256 _uniqueVoters,
        uint256 _averageRating
    ) external onlyEventOrganizer(_eventId) {
        EventStatistics storage stats = eventStatistics[_eventId];
        stats.uniqueVoters = _uniqueVoters;
        stats.averageRating = _averageRating;
        
        if (events[_eventId].currentParticipants > 0) {
            stats.completionRate = (_uniqueVoters * 100) / events[_eventId].currentParticipants;
        }
    }
    
    // ============ Query Functions ============
    
    function getEvent(uint256 _eventId) external view validEvent(_eventId) returns (EventDetails memory) {
        return events[_eventId];
    }
    
    function getEventStatistics(uint256 _eventId) external view validEvent(_eventId) returns (EventStatistics memory) {
        return eventStatistics[_eventId];
    }
    
    function isRegistered(uint256 _eventId, address _participant) external view returns (bool) {
        return eventRegistrations[_eventId][_participant];
    }
    
    function hasAttended(uint256 _eventId, address _participant) external view returns (bool) {
        return eventAttendance[_eventId][_participant];
    }
    
    function getOrganizerEvents(address _organizer) external view returns (uint256[] memory) {
        return organizerEvents[_organizer];
    }
    
    function getParticipantEvents(address _participant) external view returns (uint256[] memory) {
        return participantEvents[_participant];
    }
    
    function getActiveEvents() external view returns (uint256[] memory) {
        uint256 activeCount = 0;
        
        for (uint256 i = 0; i < nextEventId; i++) {
            if (events[i].status == EventStatus.Active || events[i].status == EventStatus.VotingOpen) {
                activeCount++;
            }
        }
        
        uint256[] memory activeEvents = new uint256[](activeCount);
        uint256 index = 0;
        
        for (uint256 i = 0; i < nextEventId; i++) {
            if (events[i].status == EventStatus.Active || events[i].status == EventStatus.VotingOpen) {
                activeEvents[index] = i;
                index++;
            }
        }
        
        return activeEvents;
    }
    
    function getUpcomingEvents() external view returns (uint256[] memory) {
        uint256 upcomingCount = 0;
        
        for (uint256 i = 0; i < nextEventId; i++) {
            if (events[i].status == EventStatus.Created && events[i].startTime > block.timestamp) {
                upcomingCount++;
            }
        }
        
        uint256[] memory upcomingEvents = new uint256[](upcomingCount);
        uint256 index = 0;
        
        for (uint256 i = 0; i < nextEventId; i++) {
            if (events[i].status == EventStatus.Created && events[i].startTime > block.timestamp) {
                upcomingEvents[index] = i;
                index++;
            }
        }
        
        return upcomingEvents;
    }
    
    function canVote(uint256 _eventId, address _participant) external view returns (bool) {
        EventDetails storage eventData = events[_eventId];
        
        if (eventData.status != EventStatus.VotingOpen) return false;
        if (block.timestamp < eventData.votingStartTime) return false;
        if (block.timestamp > eventData.votingEndTime) return false;
        
        if (eventData.requiresRegistration) {
            return eventRegistrations[_eventId][_participant];
        }
        
        return true;
    }
    
    // ============ Admin Functions ============
    
    function grantOrganizerRole(address _account) external onlyRole(ADMIN_ROLE) {
        grantRole(ORGANIZER_ROLE, _account);
    }
    
    function revokeOrganizerRole(address _account) external onlyRole(ADMIN_ROLE) {
        revokeRole(ORGANIZER_ROLE, _account);
    }
    
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }
    
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }
    
    function getTotalEvents() external view returns (uint256) {
        return nextEventId;
    }
}
