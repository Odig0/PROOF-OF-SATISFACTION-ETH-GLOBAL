// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title AnonymousVoteToken
 * @dev ERC721 token representing anonymous vote receipts
 * @notice This token is non-transferable and serves as proof of voting without revealing vote content
 */
contract AnonymousVoteToken is ERC721, AccessControl {
    
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    
    uint256 private _tokenIdCounter;
    
    struct VoteMetadata {
        uint256 eventId;
        uint256 categoryId;
        uint256 timestamp;
        bytes32 voteCommitment; // Hash of the vote without revealing actual rating
        bool isRevealed;
    }
    
    mapping(uint256 => VoteMetadata) public tokenMetadata;
    mapping(address => uint256[]) public userTokens;
    mapping(uint256 => mapping(uint256 => uint256[])) public eventCategoryTokens; // eventId => categoryId => tokenIds
    
    event VoteTokenMinted(
        address indexed voter,
        uint256 indexed tokenId,
        uint256 indexed eventId,
        uint256 categoryId,
        bytes32 voteCommitment
    );
    
    event VoteTokenBurned(uint256 indexed tokenId);
    
    constructor() ERC721("Proof of Fun Vote Token", "POFVOTE") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(BURNER_ROLE, msg.sender);
    }
    
    /**
     * @dev Mints a new vote token with anonymous metadata
     * @param _to Address to mint the token to
     * @param _eventId Event ID the vote belongs to
     * @param _categoryId Category ID the vote belongs to
     * @param _voteCommitment Hash commitment of the vote
     */
    function mintVoteToken(
        address _to,
        uint256 _eventId,
        uint256 _categoryId,
        bytes32 _voteCommitment
    ) external onlyRole(MINTER_ROLE) returns (uint256) {
        uint256 tokenId = _tokenIdCounter;
        _tokenIdCounter++;
        
        _safeMint(_to, tokenId);
        
        tokenMetadata[tokenId] = VoteMetadata({
            eventId: _eventId,
            categoryId: _categoryId,
            timestamp: block.timestamp,
            voteCommitment: _voteCommitment,
            isRevealed: false
        });
        
        userTokens[_to].push(tokenId);
        eventCategoryTokens[_eventId][_categoryId].push(tokenId);
        
        emit VoteTokenMinted(_to, tokenId, _eventId, _categoryId, _voteCommitment);
        
        return tokenId;
    }
    
    /**
     * @dev Batch mint vote tokens for multiple votes
     */
    function batchMintVoteTokens(
        address _to,
        uint256 _eventId,
        uint256[] memory _categoryIds,
        bytes32[] memory _voteCommitments
    ) external onlyRole(MINTER_ROLE) returns (uint256[] memory) {
        require(_categoryIds.length == _voteCommitments.length, "Array length mismatch");
        
        uint256[] memory tokenIds = new uint256[](_categoryIds.length);
        
        for (uint256 i = 0; i < _categoryIds.length; i++) {
            uint256 tokenId = _tokenIdCounter;
            _tokenIdCounter++;
            
            _safeMint(_to, tokenId);
            
            tokenMetadata[tokenId] = VoteMetadata({
                eventId: _eventId,
                categoryId: _categoryIds[i],
                timestamp: block.timestamp,
                voteCommitment: _voteCommitments[i],
                isRevealed: false
            });
            
            userTokens[_to].push(tokenId);
            eventCategoryTokens[_eventId][_categoryIds[i]].push(tokenId);
            
            emit VoteTokenMinted(_to, tokenId, _eventId, _categoryIds[i], _voteCommitments[i]);
            
            tokenIds[i] = tokenId;
        }
        
        return tokenIds;
    }
    
    /**
     * @dev Burns a vote token
     */
    function burnVoteToken(uint256 _tokenId) external onlyRole(BURNER_ROLE) {
        _burn(_tokenId);
        emit VoteTokenBurned(_tokenId);
    }
    
    /**
     * @dev Get all tokens owned by an address
     */
    function getUserTokens(address _user) external view returns (uint256[] memory) {
        return userTokens[_user];
    }
    
    /**
     * @dev Get all tokens for a specific event and category
     */
    function getEventCategoryTokens(uint256 _eventId, uint256 _categoryId) external view returns (uint256[] memory) {
        return eventCategoryTokens[_eventId][_categoryId];
    }
    
    /**
     * @dev Get token metadata
     */
    function getTokenMetadata(uint256 _tokenId) external view returns (VoteMetadata memory) {
        _requireOwned(_tokenId);
        return tokenMetadata[_tokenId];
    }
    
    /**
     * @dev Get total number of tokens minted
     */
    function totalSupply() external view returns (uint256) {
        return _tokenIdCounter;
    }
    
    /**
     * @dev Override transfer functions to make tokens non-transferable
     */
    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal virtual override returns (address) {
        address from = _ownerOf(tokenId);
        
        // Only allow minting (from == address(0))
        require(from == address(0), "Vote tokens are non-transferable");
        
        return super._update(to, tokenId, auth);
    }
    
    /**
     * @dev The following functions are overrides required by Solidity
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
    
    /**
     * @dev Grant minter role to an address
     */
    function grantMinterRole(address _account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(MINTER_ROLE, _account);
    }
    
    /**
     * @dev Revoke minter role from an address
     */
    function revokeMinterRole(address _account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(MINTER_ROLE, _account);
    }
}
