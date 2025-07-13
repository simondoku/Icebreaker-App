//
//  InteractionService.swift
//  Icebreaker
//
//  Created by Simon Doku on 7/13/25.
//

import Foundation
import SwiftUI
import Combine

class InteractionService: ObservableObject {
    static let shared = InteractionService()
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var userInteractions: [String: MatchInteraction] = [:]
    
    private init() {}
    
    func canInteract(with userId: String) -> Bool {
        guard let interaction = userInteractions[userId] else { return true }
        return interaction.type != .block && interaction.type != .pass
    }
    
    func getInteraction(for userId: String) -> MatchInteraction? {
        return userInteractions[userId]
    }
    
    func getConnectionStatus(for userId: String) -> ConnectionStatus {
        guard let interaction = userInteractions[userId] else { 
            return .noInteraction 
        }
        
        switch interaction.type {
        case .wave:
            return .waveSent
        case .waveReceived:
            return .waveReceived
        case .introSent:
            return .introSent
        case .conversation:
            return .connected
        case .pass:
            return .passed
        case .block:
            return .blocked
        case .introReceived:
            return .introReceived
        }
    }
    
    func sendIntroMessage(to match: MatchResult, message: String) async -> IcebreakerChatConversation? {
        await MainActor.run {
            isLoading = true
        }
        
        // Simulate API call
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        await MainActor.run {
            isLoading = false
            // Store the intro interaction
            userInteractions[match.user.id] = MatchInteraction(
                id: UUID().uuidString,
                userId: match.user.id,
                type: .introSent,
                timestamp: Date(),
                message: message
            )
        }
        
        // Create a limited conversation for intro message only
        return IcebreakerChatConversation(
            id: UUID().uuidString,
            matchId: match.user.id,
            otherUserName: match.user.firstName,
            lastMessage: message,
            lastMessageTime: Date(),
            unreadCount: 0,
            status: .introSent
        )
    }
    
    func sendWave(to match: MatchResult) async -> Bool {
        await MainActor.run {
            isLoading = true
        }
        
        // Simulate API call
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        await MainActor.run {
            isLoading = false
            // Store the wave interaction
            userInteractions[match.user.id] = MatchInteraction(
                id: UUID().uuidString,
                userId: match.user.id,
                type: .wave,
                timestamp: Date()
            )
        }
        
        // Post notification for wave delivered
        NotificationCenter.default.post(
            name: .waveDelivered,
            object: nil,
            userInfo: ["userName": match.user.firstName]
        )
        
        return true
    }
    
    func acceptWave(from match: MatchResult) async -> IcebreakerChatConversation? {
        await MainActor.run {
            isLoading = true
        }
        
        // Simulate API call
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        await MainActor.run {
            isLoading = false
            // Update to conversation status
            userInteractions[match.user.id] = MatchInteraction(
                id: UUID().uuidString,
                userId: match.user.id,
                type: .conversation,
                timestamp: Date()
            )
        }
        
        return IcebreakerChatConversation(
            id: UUID().uuidString,
            matchId: match.user.id,
            otherUserName: match.user.firstName,
            lastMessage: "Wave accepted! Start chatting.",
            lastMessageTime: Date(),
            unreadCount: 0,
            status: .connected
        )
    }
    
    func passMatch(_ match: MatchResult) async -> Bool {
        await MainActor.run {
            isLoading = true
        }
        
        // Simulate API call
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        await MainActor.run {
            isLoading = false
            userInteractions[match.user.id] = MatchInteraction(
                id: UUID().uuidString,
                userId: match.user.id,
                type: .pass,
                timestamp: Date()
            )
        }
        
        return true
    }
    
    func reportMatch(_ match: MatchResult, reason: String) async -> Bool {
        await MainActor.run {
            isLoading = true
        }
        
        // Simulate API call
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        await MainActor.run {
            isLoading = false
        }
        
        return true
    }
    
    func blockMatch(_ match: MatchResult) async -> Bool {
        await MainActor.run {
            isLoading = true
        }
        
        // Simulate API call
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        await MainActor.run {
            isLoading = false
            userInteractions[match.user.id] = MatchInteraction(
                id: UUID().uuidString,
                userId: match.user.id,
                type: .block,
                timestamp: Date()
            )
        }
        
        return true
    }
}