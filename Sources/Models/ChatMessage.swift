import Foundation
import SwiftData

@Model
final class ChatMessage {
    @Attribute(.unique) var id: UUID
    /// The URL of the ResearchItem this chat belongs to.
    var itemURL: String
    /// "user" or "assistant"
    var role: String
    var content: String
    var timestamp: Date

    init(itemURL: String, role: String, content: String) {
        self.id = UUID()
        self.itemURL = itemURL
        self.role = role
        self.content = content
        self.timestamp = Date()
    }

    var isUser: Bool { role == "user" }
}
