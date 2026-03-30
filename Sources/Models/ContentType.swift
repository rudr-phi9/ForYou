import Foundation

/// Type of research content source.
enum ContentType: String, Codable, CaseIterable {
    case paper = "paper"
    case blog = "blog"
    case talk = "talk"
    case unknown = "unknown"

    var displayName: String {
        switch self {
        case .paper: return "Research Paper"
        case .blog: return "Technical Blog"
        case .talk: return "Talk / Lecture"
        case .unknown: return "Content"
        }
    }

    var iconName: String {
        switch self {
        case .paper: return "doc.text"
        case .blog: return "globe"
        case .talk: return "play.rectangle"
        case .unknown: return "doc"
        }
    }
}
