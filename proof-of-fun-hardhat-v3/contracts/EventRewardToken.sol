// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title EventRewardToken
 * @notice Token de recompensa NO TRANSFERIBLE (Soulbound) para eventos
 * @dev Los tokens se otorgan por asistencia y completar encuestas
 * Solo se pueden canjear por merchandise, no tienen valor económico
 */
contract EventRewardToken is ERC20, AccessControl, Pausable {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    // Metadata del evento
    string public eventName;
    uint256 public eventId;

    // Configuración de recompensas
    uint256 public attendanceReward;  // Tokens por asistir
    uint256 public surveyReward;      // Tokens por completar encuesta

    // Tracking
    mapping(address => bool) public hasClaimedAttendance;
    mapping(address => bool) public hasClaimedSurvey;

    event AttendanceRewarded(address indexed user, uint256 amount);
    event SurveyRewarded(address indexed user, uint256 amount);
    event TokensBurned(address indexed user, uint256 amount, string reason);

    constructor(
        string memory _eventName,
        uint256 _eventId,
        uint256 _attendanceReward,
        uint256 _surveyReward
    ) ERC20(
        string(abi.encodePacked("Proof of Fun - ", _eventName)),
        string(abi.encodePacked("POF-", _eventName))
    ) {
        eventName = _eventName;
        eventId = _eventId;
        attendanceReward = _attendanceReward * 10**decimals();
        surveyReward = _surveyReward * 10**decimals();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(BURNER_ROLE, msg.sender);
    }

    /**
     * @notice OVERRIDE: Los tokens NO son transferibles (Soulbound)
     * @dev Solo permite mint y burn, bloquea transferencias normales
     */
    function _update(
        address from,
        address to,
        uint256 value
    ) internal virtual override {
        // Permitir mint (from == address(0))
        if (from == address(0)) {
            super._update(from, to, value);
            return;
        }

        // Permitir burn (to == address(0))
        if (to == address(0)) {
            super._update(from, to, value);
            return;
        }

        // Bloquear cualquier otra transferencia
        revert("EventRewardToken: tokens are non-transferable (soulbound)");
    }

    /**
     * @notice Otorga tokens por asistencia al evento
     * @param user Dirección del asistente
     */
    function rewardAttendance(address user) 
        external 
        onlyRole(MINTER_ROLE) 
        whenNotPaused 
    {
        require(user != address(0), "Invalid user address");
        require(!hasClaimedAttendance[user], "Attendance already claimed");

        hasClaimedAttendance[user] = true;
        _mint(user, attendanceReward);

        emit AttendanceRewarded(user, attendanceReward);
    }

    /**
     * @notice Otorga tokens por completar encuesta
     * @param user Dirección del usuario
     */
    function rewardSurvey(address user) 
        external 
        onlyRole(MINTER_ROLE) 
        whenNotPaused 
    {
        require(user != address(0), "Invalid user address");
        require(!hasClaimedSurvey[user], "Survey already claimed");
        require(hasClaimedAttendance[user], "Must attend event first");

        hasClaimedSurvey[user] = true;
        _mint(user, surveyReward);

        emit SurveyRewarded(user, surveyReward);
    }

    /**
     * @notice Quema tokens (usado para canjear merchandise)
     * @param user Dirección del usuario
     * @param amount Cantidad de tokens a quemar
     * @param reason Razón del quemado (ej: "Canje polera talla M")
     */
    function burnFrom(
        address user, 
        uint256 amount, 
        string memory reason
    ) 
        external 
        onlyRole(BURNER_ROLE) 
    {
        require(balanceOf(user) >= amount, "Insufficient balance");
        _burn(user, amount);

        emit TokensBurned(user, amount, reason);
    }

    /**
     * @notice Verifica si un usuario ha reclamado todas las recompensas
     */
    function hasClaimedAll(address user) external view returns (bool) {
        return hasClaimedAttendance[user] && hasClaimedSurvey[user];
    }

    /**
     * @notice Obtiene el progreso de recompensas de un usuario
     */
    function getUserProgress(address user) external view returns (
        bool attendanceClaimed,
        bool surveyClaimed,
        uint256 currentBalance,
        uint256 totalPossibleRewards
    ) {
        return (
            hasClaimedAttendance[user],
            hasClaimedSurvey[user],
            balanceOf(user),
            attendanceReward + surveyReward
        );
    }

    // Funciones de administración
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function grantMinterRole(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(MINTER_ROLE, account);
    }

    function grantBurnerRole(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(BURNER_ROLE, account);
    }
}
