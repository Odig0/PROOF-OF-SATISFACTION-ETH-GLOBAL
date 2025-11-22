// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./EventRewardToken.sol";

/**
 * @title MerchRedemption
 * @notice Sistema de canje de tokens de recompensa por merchandise
 * @dev Los tokens se queman al canjear, no tienen valor económico real
 */
contract MerchRedemption is AccessControl, ReentrancyGuard, Pausable {
    bytes32 public constant ORGANIZER_ROLE = keccak256("ORGANIZER_ROLE");
    bytes32 public constant FULFILLER_ROLE = keccak256("FULFILLER_ROLE");

    // ============ Structs ============

    struct MerchItem {
        uint256 id;
        string name;
        string description;
        string imageUrl;
        uint256 tokenPrice;
        uint256 stock;
        uint256 maxPerUser;
        bool isActive;
        string[] sizes; // ["S", "M", "L", "XL"] para ropa
        string category; // "clothing", "accessories", "tech", "other"
    }

    struct Redemption {
        uint256 id;
        address user;
        uint256 itemId;
        uint256 quantity;
        string size;
        uint256 tokensBurned;
        uint256 timestamp;
        RedemptionStatus status;
        string trackingInfo;
        address rewardToken;
    }

    enum RedemptionStatus {
        Pending,      // Esperando procesamiento
        Confirmed,    // Confirmado por el organizador
        Shipped,      // Enviado
        Delivered,    // Entregado
        Cancelled     // Cancelado
    }

    // ============ State Variables ============

    uint256 public nextItemId;
    uint256 public nextRedemptionId;

    mapping(uint256 => MerchItem) public merchItems;
    mapping(uint256 => Redemption) public redemptions;
    mapping(address => uint256[]) public userRedemptions;
    mapping(uint256 => mapping(address => uint256)) public userItemRedemptions; // itemId => user => count
    mapping(address => bool) public supportedTokens; // Tokens de recompensa aceptados

    // ============ Events ============

    event MerchItemCreated(uint256 indexed itemId, string name, uint256 tokenPrice);
    event MerchItemUpdated(uint256 indexed itemId, string name, uint256 tokenPrice);
    event MerchItemStockUpdated(uint256 indexed itemId, uint256 newStock);
    event TokenRedeemed(
        uint256 indexed redemptionId,
        address indexed user,
        uint256 itemId,
        uint256 quantity,
        uint256 tokensBurned
    );
    event RedemptionStatusUpdated(uint256 indexed redemptionId, RedemptionStatus status);
    event RedemptionCancelled(uint256 indexed redemptionId, uint256 tokensRefunded);
    event RewardTokenAdded(address indexed token);
    event RewardTokenRemoved(address indexed token);

    // ============ Constructor ============

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ORGANIZER_ROLE, msg.sender);
        _grantRole(FULFILLER_ROLE, msg.sender);
    }

    // ============ Merchandise Management ============

    function createMerchItem(
        string memory _name,
        string memory _description,
        string memory _imageUrl,
        uint256 _tokenPrice,
        uint256 _stock,
        uint256 _maxPerUser,
        string[] memory _sizes,
        string memory _category
    ) external onlyRole(ORGANIZER_ROLE) returns (uint256) {
        require(bytes(_name).length > 0, "Name cannot be empty");
        require(_tokenPrice > 0, "Price must be greater than 0");
        require(_maxPerUser > 0, "Max per user must be greater than 0");

        uint256 itemId = nextItemId++;

        MerchItem storage item = merchItems[itemId];
        item.id = itemId;
        item.name = _name;
        item.description = _description;
        item.imageUrl = _imageUrl;
        item.tokenPrice = _tokenPrice;
        item.stock = _stock;
        item.maxPerUser = _maxPerUser;
        item.isActive = true;
        item.sizes = _sizes;
        item.category = _category;

        emit MerchItemCreated(itemId, _name, _tokenPrice);

        return itemId;
    }

    function updateMerchItem(
        uint256 _itemId,
        string memory _name,
        string memory _description,
        string memory _imageUrl,
        uint256 _tokenPrice,
        uint256 _maxPerUser
    ) external onlyRole(ORGANIZER_ROLE) {
        require(_itemId < nextItemId, "Invalid item ID");
        require(bytes(_name).length > 0, "Name cannot be empty");
        require(_tokenPrice > 0, "Price must be greater than 0");

        MerchItem storage item = merchItems[_itemId];
        item.name = _name;
        item.description = _description;
        item.imageUrl = _imageUrl;
        item.tokenPrice = _tokenPrice;
        item.maxPerUser = _maxPerUser;

        emit MerchItemUpdated(_itemId, _name, _tokenPrice);
    }

    function updateStock(uint256 _itemId, uint256 _newStock) external onlyRole(ORGANIZER_ROLE) {
        require(_itemId < nextItemId, "Invalid item ID");
        
        merchItems[_itemId].stock = _newStock;
        
        emit MerchItemStockUpdated(_itemId, _newStock);
    }

    function toggleItemActive(uint256 _itemId) external onlyRole(ORGANIZER_ROLE) {
        require(_itemId < nextItemId, "Invalid item ID");
        
        merchItems[_itemId].isActive = !merchItems[_itemId].isActive;
    }

    // ============ Reward Token Management ============

    function addSupportedToken(address _token) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_token != address(0), "Invalid token address");
        supportedTokens[_token] = true;
        emit RewardTokenAdded(_token);
    }

    function removeSupportedToken(address _token) external onlyRole(DEFAULT_ADMIN_ROLE) {
        supportedTokens[_token] = false;
        emit RewardTokenRemoved(_token);
    }

    // ============ Redemption Functions ============

    function redeemMerch(
        uint256 _itemId,
        uint256 _quantity,
        string memory _size,
        address _rewardToken
    ) external nonReentrant whenNotPaused returns (uint256) {
        require(_itemId < nextItemId, "Invalid item ID");
        require(_quantity > 0, "Quantity must be greater than 0");
        require(supportedTokens[_rewardToken], "Token not supported");

        MerchItem storage item = merchItems[_itemId];
        require(item.isActive, "Item not available");
        require(item.stock >= _quantity, "Insufficient stock");
        require(
            userItemRedemptions[_itemId][msg.sender] + _quantity <= item.maxPerUser,
            "Exceeds max per user"
        );

        // Verificar que el usuario tenga suficiente balance si requiere talla
        if (item.sizes.length > 0) {
            require(bytes(_size).length > 0, "Size required");
            bool validSize = false;
            for (uint256 i = 0; i < item.sizes.length; i++) {
                if (keccak256(bytes(item.sizes[i])) == keccak256(bytes(_size))) {
                    validSize = true;
                    break;
                }
            }
            require(validSize, "Invalid size");
        }

        uint256 totalCost = item.tokenPrice * _quantity;
        EventRewardToken rewardToken = EventRewardToken(_rewardToken);
        
        require(rewardToken.balanceOf(msg.sender) >= totalCost, "Insufficient token balance");

        // Quemar tokens
        rewardToken.burnFrom(msg.sender, totalCost, string(abi.encodePacked("Redeemed: ", item.name)));

        // Crear redención
        uint256 redemptionId = nextRedemptionId++;

        Redemption storage redemption = redemptions[redemptionId];
        redemption.id = redemptionId;
        redemption.user = msg.sender;
        redemption.itemId = _itemId;
        redemption.quantity = _quantity;
        redemption.size = _size;
        redemption.tokensBurned = totalCost;
        redemption.timestamp = block.timestamp;
        redemption.status = RedemptionStatus.Pending;
        redemption.rewardToken = _rewardToken;

        // Actualizar estado
        item.stock -= _quantity;
        userItemRedemptions[_itemId][msg.sender] += _quantity;
        userRedemptions[msg.sender].push(redemptionId);

        emit TokenRedeemed(redemptionId, msg.sender, _itemId, _quantity, totalCost);

        return redemptionId;
    }

    function updateRedemptionStatus(
        uint256 _redemptionId,
        RedemptionStatus _status,
        string memory _trackingInfo
    ) external onlyRole(FULFILLER_ROLE) {
        require(_redemptionId < nextRedemptionId, "Invalid redemption ID");
        require(_status != RedemptionStatus.Pending, "Cannot set to pending");

        Redemption storage redemption = redemptions[_redemptionId];
        require(redemption.status != RedemptionStatus.Cancelled, "Redemption cancelled");
        require(redemption.status != RedemptionStatus.Delivered, "Already delivered");

        redemption.status = _status;
        if (bytes(_trackingInfo).length > 0) {
            redemption.trackingInfo = _trackingInfo;
        }

        emit RedemptionStatusUpdated(_redemptionId, _status);
    }

    function cancelRedemption(uint256 _redemptionId) external {
        require(_redemptionId < nextRedemptionId, "Invalid redemption ID");

        Redemption storage redemption = redemptions[_redemptionId];
        require(
            msg.sender == redemption.user || hasRole(ORGANIZER_ROLE, msg.sender),
            "Unauthorized"
        );
        require(redemption.status == RedemptionStatus.Pending, "Can only cancel pending redemptions");

        // Restaurar stock
        MerchItem storage item = merchItems[redemption.itemId];
        item.stock += redemption.quantity;
        userItemRedemptions[redemption.itemId][redemption.user] -= redemption.quantity;

        // Nota: Los tokens ya fueron quemados, no se pueden recuperar
        // Esto incentiva a no cancelar canjes innecesariamente

        redemption.status = RedemptionStatus.Cancelled;

        emit RedemptionCancelled(_redemptionId, redemption.tokensBurned);
    }

    // ============ View Functions ============

    function getMerchItem(uint256 _itemId) external view returns (
        uint256 id,
        string memory name,
        string memory description,
        string memory imageUrl,
        uint256 tokenPrice,
        uint256 stock,
        uint256 maxPerUser,
        bool isActive,
        string[] memory sizes,
        string memory category
    ) {
        require(_itemId < nextItemId, "Invalid item ID");
        MerchItem storage item = merchItems[_itemId];
        return (
            item.id,
            item.name,
            item.description,
            item.imageUrl,
            item.tokenPrice,
            item.stock,
            item.maxPerUser,
            item.isActive,
            item.sizes,
            item.category
        );
    }

    function getRedemption(uint256 _redemptionId) external view returns (
        uint256 id,
        address user,
        uint256 itemId,
        uint256 quantity,
        string memory size,
        uint256 tokensBurned,
        uint256 timestamp,
        RedemptionStatus status,
        string memory trackingInfo
    ) {
        require(_redemptionId < nextRedemptionId, "Invalid redemption ID");
        Redemption storage redemption = redemptions[_redemptionId];
        return (
            redemption.id,
            redemption.user,
            redemption.itemId,
            redemption.quantity,
            redemption.size,
            redemption.tokensBurned,
            redemption.timestamp,
            redemption.status,
            redemption.trackingInfo
        );
    }

    function getUserRedemptions(address _user) external view returns (uint256[] memory) {
        return userRedemptions[_user];
    }

    function getUserItemRedemptionCount(uint256 _itemId, address _user) external view returns (uint256) {
        return userItemRedemptions[_itemId][_user];
    }

    // ============ Admin Functions ============

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function grantOrganizerRole(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(ORGANIZER_ROLE, account);
    }

    function grantFulfillerRole(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(FULFILLER_ROLE, account);
    }
}
