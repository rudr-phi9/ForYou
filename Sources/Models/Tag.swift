import Foundation
import SwiftData

@Model
final class Tag {
    @Attribute(.unique) var id: UUID
    var name: String
    var isActive: Bool
    var createdAt: Date

    init(name: String) {
        self.id = UUID()
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.isActive = true
        self.createdAt = Date()
    }

    /// Normalised lowercase name for search queries.
    var queryName: String {
        name.lowercased().replacingOccurrences(of: " ", with: "+")
    }

    /// Display-friendly hashtag form.
    var hashtag: String {
        "#\(name.replacingOccurrences(of: " ", with: "_"))"
    }
}
