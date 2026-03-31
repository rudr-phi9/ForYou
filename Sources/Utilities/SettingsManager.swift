import Foundation

/// Manages user-configurable settings via UserDefaults.
final class SettingsManager {
    static let shared = SettingsManager()

    private let defaults = UserDefaults.standard

    // MARK: - Keys

    private enum Key: String {
        case geminiAPIKey = "gemini_api_key"
        case youtubeAPIKey = "youtube_api_key"
        case syncIntervalHours = "sync_interval_hours"
        case lastSyncDate = "last_sync_date"
    }

    // MARK: - Gemini API Key

    /// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    /// ✦  SET YOUR GEMINI API KEY HERE  (or in the app UI)  ✦
    /// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    var geminiAPIKey: String {
        get { (defaults.string(forKey: Key.geminiAPIKey.rawValue) ?? "").trimmingCharacters(in: .whitespacesAndNewlines.union(.init(charactersIn: ","))) }
        set { defaults.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines.union(.init(charactersIn: ","))), forKey: Key.geminiAPIKey.rawValue) }
    }

    var hasAPIKey: Bool { !geminiAPIKey.isEmpty }

    // MARK: - YouTube API Key

    var youtubeAPIKey: String {
        get { (defaults.string(forKey: Key.youtubeAPIKey.rawValue) ?? "").trimmingCharacters(in: .whitespacesAndNewlines.union(.init(charactersIn: ","))) }
        set { defaults.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines.union(.init(charactersIn: ","))), forKey: Key.youtubeAPIKey.rawValue) }
    }

    var hasYouTubeKey: Bool { !youtubeAPIKey.isEmpty }

    // MARK: - Sync Interval

    var syncIntervalHours: Double {
        get {
            let val = defaults.double(forKey: Key.syncIntervalHours.rawValue)
            return val > 0 ? val : 2.0   // default 2 hours
        }
        set { defaults.set(newValue, forKey: Key.syncIntervalHours.rawValue) }
    }

    var syncIntervalSeconds: TimeInterval { syncIntervalHours * 3600 }

    // MARK: - Last Sync

    var lastSyncDate: Date? {
        get { defaults.object(forKey: Key.lastSyncDate.rawValue) as? Date }
        set { defaults.set(newValue, forKey: Key.lastSyncDate.rawValue) }
    }

    // MARK: - Excluded Domains (News Filter)

    let excludedDomains: [String] = [
        "cnn.com", "bbc.com", "reuters.com", "apnews.com",
        "nytimes.com", "washingtonpost.com", "foxnews.com",
        "theguardian.com", "nbcnews.com", "abcnews.go.com",
        "usatoday.com", "huffpost.com", "buzzfeed.com",
        "dailymail.co.uk", "msn.com"
    ]

    private init() {}
}
