import Foundation

struct ChatConversation: Identifiable, Codable {
    let id: String
    let matchId: String
    let otherUserName: String
    var lastMessage: String
    var lastMessageTime: Date
    var unreadCount: Int
}