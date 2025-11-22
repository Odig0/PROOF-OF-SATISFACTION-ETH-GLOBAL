// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title VoteCommitment
 * @dev Handles vote commitments using commit-reveal scheme for additional privacy
 */
library VoteCommitment {
    
    struct Commitment {
        bytes32 commitment;
        uint256 timestamp;
        bool revealed;
    }
    
    /**
     * @dev Generate a commitment hash for a vote
     * @param _voter Address of the voter
     * @param _eventId Event ID
     * @param _categoryId Category ID
     * @param _rating Vote rating (1-5)
     * @param _salt Random salt for privacy
     * @return commitment hash
     */
    function generateCommitment(
        address _voter,
        uint256 _eventId,
        uint256 _categoryId,
        uint8 _rating,
        bytes32 _salt
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(
            _voter,
            _eventId,
            _categoryId,
            _rating,
            _salt
        ));
    }
    
    /**
     * @dev Verify a commitment matches the revealed values
     */
    function verifyCommitment(
        bytes32 _commitment,
        address _voter,
        uint256 _eventId,
        uint256 _categoryId,
        uint8 _rating,
        bytes32 _salt
    ) internal pure returns (bool) {
        bytes32 calculatedCommitment = generateCommitment(
            _voter,
            _eventId,
            _categoryId,
            _rating,
            _salt
        );
        return _commitment == calculatedCommitment;
    }
    
    /**
     * @dev Generate a batch commitment for multiple votes
     */
    function generateBatchCommitment(
        address _voter,
        uint256 _eventId,
        uint256[] memory _categoryIds,
        uint8[] memory _ratings,
        bytes32 _salt
    ) internal pure returns (bytes32) {
        require(_categoryIds.length == _ratings.length, "Array length mismatch");
        
        return keccak256(abi.encodePacked(
            _voter,
            _eventId,
            _categoryIds,
            _ratings,
            _salt
        ));
    }
}

/**
 * @title AnonymityHelper
 * @dev Helper library for maintaining voter anonymity
 */
library AnonymityHelper {
    
    /**
     * @dev Generate an anonymous voter ID
     */
    function generateAnonymousId(
        address _voter,
        uint256 _eventId,
        bytes32 _secret
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_voter, _eventId, _secret));
    }
    
    /**
     * @dev Create a nullifier to prevent double voting
     */
    function generateNullifier(
        address _voter,
        uint256 _eventId,
        uint256 _categoryId
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(
            "NULLIFIER",
            _voter,
            _eventId,
            _categoryId,
            block.timestamp
        ));
    }
    
    /**
     * @dev Generate a vote proof hash
     */
    function generateVoteProof(
        bytes32 _anonymousId,
        uint256 _eventId,
        uint256 _categoryId,
        uint256 _timestamp
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(
            _anonymousId,
            _eventId,
            _categoryId,
            _timestamp
        ));
    }
}

/**
 * @title RatingCalculator
 * @dev Library for calculating ratings and statistics
 */
library RatingCalculator {
    
    uint256 constant PRECISION = 100;
    
    /**
     * @dev Calculate weighted average rating
     */
    function calculateAverage(
        uint256[5] memory _voteCounts
    ) internal pure returns (uint256) {
        uint256 totalVotes = 0;
        uint256 weightedSum = 0;
        
        for (uint8 i = 0; i < 5; i++) {
            uint8 rating = i + 1;
            totalVotes += _voteCounts[i];
            weightedSum += _voteCounts[i] * rating;
        }
        
        if (totalVotes == 0) return 0;
        
        return (weightedSum * PRECISION) / totalVotes;
    }
    
    /**
     * @dev Calculate median rating
     */
    function calculateMedian(
        uint256[5] memory _voteCounts
    ) internal pure returns (uint8) {
        uint256 totalVotes = 0;
        for (uint8 i = 0; i < 5; i++) {
            totalVotes += _voteCounts[i];
        }
        
        if (totalVotes == 0) return 0;
        
        uint256 medianPosition = totalVotes / 2;
        uint256 currentCount = 0;
        
        for (uint8 i = 0; i < 5; i++) {
            currentCount += _voteCounts[i];
            if (currentCount >= medianPosition) {
                return i + 1;
            }
        }
        
        return 3; // Default to middle rating
    }
    
    /**
     * @dev Calculate mode (most frequent rating)
     */
    function calculateMode(
        uint256[5] memory _voteCounts
    ) internal pure returns (uint8) {
        uint256 maxCount = 0;
        uint8 mode = 1;
        
        for (uint8 i = 0; i < 5; i++) {
            if (_voteCounts[i] > maxCount) {
                maxCount = _voteCounts[i];
                mode = i + 1;
            }
        }
        
        return mode;
    }
    
    /**
     * @dev Calculate standard deviation (scaled by PRECISION)
     */
    function calculateStandardDeviation(
        uint256[5] memory _voteCounts,
        uint256 _average
    ) internal pure returns (uint256) {
        uint256 totalVotes = 0;
        uint256 variance = 0;
        
        for (uint8 i = 0; i < 5; i++) {
            totalVotes += _voteCounts[i];
        }
        
        if (totalVotes == 0) return 0;
        
        for (uint8 i = 0; i < 5; i++) {
            uint8 rating = i + 1;
            uint256 ratingScaled = rating * PRECISION;
            int256 diff = int256(ratingScaled) - int256(_average);
            uint256 squaredDiff = uint256(diff * diff);
            variance += _voteCounts[i] * squaredDiff;
        }
        
        variance = variance / totalVotes;
        
        return sqrt(variance);
    }
    
    /**
     * @dev Calculate square root (Babylonian method)
     */
    function sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        
        return y;
    }
    
    /**
     * @dev Calculate percentage distribution
     */
    function calculateDistribution(
        uint256[5] memory _voteCounts
    ) internal pure returns (uint256[5] memory) {
        uint256 totalVotes = 0;
        uint256[5] memory distribution;
        
        for (uint8 i = 0; i < 5; i++) {
            totalVotes += _voteCounts[i];
        }
        
        if (totalVotes == 0) return distribution;
        
        for (uint8 i = 0; i < 5; i++) {
            distribution[i] = (_voteCounts[i] * 10000) / totalVotes; // Percentage * 100
        }
        
        return distribution;
    }
}

/**
 * @title ValidationHelper
 * @dev Helper library for input validation
 */
library ValidationHelper {
    
    function isValidRating(uint8 _rating) internal pure returns (bool) {
        return _rating >= 1 && _rating <= 5;
    }
    
    function isValidTimeRange(uint256 _startTime, uint256 _endTime) internal view returns (bool) {
        return _startTime < _endTime && _startTime > block.timestamp;
    }
    
    function isValidVotingPeriod(
        uint256 _votingStart,
        uint256 _votingEnd,
        uint256 _eventStart,
        uint256 _eventEnd
    ) internal pure returns (bool) {
        return _votingStart >= _eventStart &&
               _votingEnd <= _eventEnd &&
               _votingStart < _votingEnd;
    }
    
    function isEventActive(
        uint256 _startTime,
        uint256 _endTime
    ) internal view returns (bool) {
        return block.timestamp >= _startTime && block.timestamp <= _endTime;
    }
    
    function isVotingOpen(
        uint256 _votingStart,
        uint256 _votingEnd
    ) internal view returns (bool) {
        return block.timestamp >= _votingStart && block.timestamp <= _votingEnd;
    }
}
