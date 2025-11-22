// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./ProofOfFun.sol";
import "./EventManager.sol";
import "./AnonymousVoteToken.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title ProofOfFunFactory
 * @dev Factory contract for deploying and managing the complete Proof of Fun ecosystem
 */
contract ProofOfFunFactory is AccessControl, ReentrancyGuard {
    
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    
    struct Deployment {
        address proofOfFun;
        address eventManager;
        address voteToken;
        uint256 timestamp;
        address deployer;
    }
    
    Deployment[] public deployments;
    mapping(address => uint256[]) public userDeployments;
    
    event SystemDeployed(
        address indexed deployer,
        address proofOfFun,
        address eventManager,
        address voteToken,
        uint256 indexed deploymentId
    );
    
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }
    
    function deployProofOfFunSystem() external nonReentrant returns (
        address proofOfFunAddress,
        address eventManagerAddress,
        address voteTokenAddress
    ) {
        // Deploy contracts
        ProofOfFun proofOfFun = new ProofOfFun();
        EventManager eventManager = new EventManager();
        AnonymousVoteToken voteToken = new AnonymousVoteToken();
        
        // Grant necessary roles
        eventManager.grantRole(eventManager.ORGANIZER_ROLE(), msg.sender);
        voteToken.grantMinterRole(address(proofOfFun));
        
        // Transfer ownership
        proofOfFun.transferOwnership(msg.sender);
        
        // Record deployment
        uint256 deploymentId = deployments.length;
        deployments.push(Deployment({
            proofOfFun: address(proofOfFun),
            eventManager: address(eventManager),
            voteToken: address(voteToken),
            timestamp: block.timestamp,
            deployer: msg.sender
        }));
        
        userDeployments[msg.sender].push(deploymentId);
        
        emit SystemDeployed(
            msg.sender,
            address(proofOfFun),
            address(eventManager),
            address(voteToken),
            deploymentId
        );
        
        return (address(proofOfFun), address(eventManager), address(voteToken));
    }
    
    function getDeployment(uint256 _deploymentId) external view returns (Deployment memory) {
        require(_deploymentId < deployments.length, "Invalid deployment ID");
        return deployments[_deploymentId];
    }
    
    function getUserDeployments(address _user) external view returns (uint256[] memory) {
        return userDeployments[_user];
    }
    
    function getTotalDeployments() external view returns (uint256) {
        return deployments.length;
    }
}
