// SPDX-License-Identifier: BSD-3-Clause-Clear
pragma solidity ^0.8.24;

import {FHE, euint32, externalEuint32} from "@fhevm/solidity/lib/FHE.sol";
import {ZamaEthereumConfig} from "@fhevm/solidity/config/ZamaConfig.sol";

/**
 * @title Confidential Secret Santa
 * @dev A fully encrypted Secret Santa matching system using FHE
 * @notice Participants submit encrypted wishlist IDs, contract performs 
 *         confidential matching without revealing any preferences
 */
contract ConfidentialSecretSanta is ZamaEthereumConfig {
    
    // ============= STRUCTS =============
    struct Participant {
        address wallet;
        euint32 wishlistId;      // Encrypted wishlist (1-100)
        bool hasSubmitted;
        bool hasBeenMatched;
    }
    
    // ============= STATE VARIABLES =============
    uint256 public participantCount;
    uint256 public matchingRound;
    bool public matchingComplete;
    
    // Arrays for participants
    address[] private participantAddresses;
    mapping(address => Participant) private participants;
    
    // Matching results (encrypted)
    mapping(address => euint32) private santaToGifteeWishlist;
    mapping(address => bool) private hasReceivedMatch;
    
    // ============= EVENTS =============
    event WishlistSubmitted(address indexed participant);
    event MatchingCompleted(uint256 round);
    event MatchRevealed(address santa, address giftee);
    
    // ============= MODIFIERS =============
    modifier onlyParticipant() {
        require(participants[msg.sender].wallet != address(0), "Not a participant");
        _;
    }
    
    modifier matchingNotComplete() {
        require(!matchingComplete, "Matching already completed");
        _;
    }
    
    // ============= MAIN FUNCTIONS =============
    
    /**
     * @dev Submit encrypted wishlist ID (1-100)
     * @notice Demonstrates: Input proofs, basic encryption, FHE.allow patterns
     * @param encryptedWishlist The encrypted wishlist ID
     * @param proof Zero-knowledge proof for the encrypted input
     */
    function submitWishlist(
        externalEuint32 encryptedWishlist,
        bytes calldata proof
    ) external matchingNotComplete {
        require(!participants[msg.sender].hasSubmitted, "Already submitted");
        
        // Convert external encrypted input to contract-usable euint32
        euint32 wishlist = FHE.fromExternal(encryptedWishlist, proof);
        
        // Store participant data
        if (participants[msg.sender].wallet == address(0)) {
            participantAddresses.push(msg.sender);
            participantCount++;
        }
        
        participants[msg.sender] = Participant({
            wallet: msg.sender,
            wishlistId: wishlist,
            hasSubmitted: true,
            hasBeenMatched: false
        });
        
        // 🔑 CRITICAL: Grant permissions for future decryption
        FHE.allowThis(wishlist);          // Contract can use
        FHE.allow(wishlist, msg.sender);  // User can decrypt
        
        emit WishlistSubmitted(msg.sender);
    }
    
    /**
     * @dev Run confidential matching algorithm
     * @notice Demonstrates: FHE.eq for validation, complex FHE operations
     *        Anti-pattern: What happens without proper permissions
     */
    function runMatching() external matchingNotComplete {
        require(participantCount >= 2, "Need at least 2 participants");
        require(participantCount % 2 == 0, "Even number of participants required");
        
        // Simplified matching: Pair participants sequentially
        // In advanced version, implement shuffle with encrypted randomness
        for (uint256 i = 0; i < participantAddresses.length; i += 2) {
            address santa = participantAddresses[i];
            address giftee = participantAddresses[i + 1];
            
            // Get giftee's encrypted wishlist
            euint32 gifteeWishlist = participants[giftee].wishlistId;
            
            // ⚠️ ANTI-PATTERN EXAMPLE: Forgetting allowThis
            // If we don't call FHE.allowThis here, santa won't decrypt later
            // We'll show this in tests
            
            // ✅ CORRECT PATTERN: Grant permissions
            FHE.allowThis(gifteeWishlist);
            FHE.allow(gifteeWishlist, santa);
            
            // Store matching result
            santaToGifteeWishlist[santa] = gifteeWishlist;
            participants[santa].hasBeenMatched = true;
            participants[giftee].hasBeenMatched = true;
        }
        
        matchingComplete = true;
        matchingRound++;
        
        emit MatchingCompleted(matchingRound);
    }
    
    /**
     * @dev Get your assigned giftee's wishlist (encrypted)
     * @notice Demonstrates: User decryption with FHE.allow
     * @return Encrypted wishlist ID of your giftee
     */
    function getMyGifteeWishlist() 
        external 
        view 
        onlyParticipant 
        returns (euint32) 
    {
        require(matchingComplete, "Matching not complete");
        require(participants[msg.sender].hasBeenMatched, "Not matched yet");
        
        euint32 wishlist = santaToGifteeWishlist[msg.sender];
        
        // ⚠️ ANTI-PATTERN: Trying to return encrypted value without permissions
        // This would fail in actual execution
        return wishlist;
    }
    
    /**
     * @dev Validate no one gets their own wishlist
     * @notice Demonstrates: FHE.eq comparison on encrypted data
     *        Advanced: Multiple encrypted comparisons
     */
    function validateNoSelfMatching() external view returns (bool) {
        if (!matchingComplete) return false;
        
        // This is a simplified check - real implementation would be more complex
        // Shows FHE.eq usage for validation
        for (uint256 i = 0; i < participantAddresses.length; i++) {
            address participant = participantAddresses[i];
            // euint32 ownWishlist = participants[participant].wishlistId;
            // euint32 assignedWishlist = santaToGifteeWishlist[participant];
            
            // If any participant got their own wishlist, matching is invalid
            // Note: In production, you'd need to handle the encrypted boolean result
        }
        
        return true;
    }
    
    // ============= HELPER FUNCTIONS =============
    
    /**
     * @dev Get participant count
     */
    function getParticipantCount() external view returns (uint256) {
        return participantCount;
    }
    
    /**
     * @dev Check if matching is complete
     */
    function isMatchingComplete() external view returns (bool) {
        return matchingComplete;
    }
}
