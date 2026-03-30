import Foundation
import SwiftData

@Model
final class ResearchItem {
    @Attribute(.unique) var id: UUID
    var title: String
    var url: String
    var sourceTypeRaw: String
    var sourceName: String
    var thumbnailURL: String?
    var heroImageURL: String?
    var timestamp: Date
    var geminiSummary: String?
    var keyTakeaways: [String]
    var isRead: Bool
    var isBookmarked: Bool
    var isFavorited: Bool
    var isSummarized: Bool
    var isDiscarded: Bool
    var tagNames: [String]
    /// Importance score 0-10 based on author h-index and content quality.
    var importanceScore: Double
    /// Brief author credibility metric from Gemini.
    var authorMetric: String?
    /// Author names for papers.
    var authors: [String]
    /// Raw text content fetched for summarisation (not displayed).
    var rawTextContent: String?

    init(
        title: String,
        url: String,
        sourceType: ContentType,
        sourceName: String,
        tagNames: [String] = []
    ) {
        self.id = UUID()
        self.title = title
        self.url = url
        self.sourceTypeRaw = sourceType.rawValue
        self.sourceName = sourceName
        self.timestamp = Date()
        self.keyTakeaways = []
        self.isRead = false
        self.isBookmarked = false
        self.isFavorited = false
        self.isSummarized = false
        self.isDiscarded = false
        self.tagNames = tagNames
        self.importanceScore = 0
        self.authors = []
    }

    // MARK: - Computed Helpers

    var sourceType: ContentType {
        ContentType(rawValue: sourceTypeRaw) ?? .unknown
    }

    var isRecent: Bool {
        timestamp > Date().addingTimeInterval(-24 * 60 * 60)
    }

    var formattedTimestamp: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }

    var sourceURL: URL? { URL(string: url) }
}
