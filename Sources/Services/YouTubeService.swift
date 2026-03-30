import Foundation

/// Searches YouTube Data API v3 for academic talks and lectures.
/// Requires a YouTube Data API key (uses the same Gemini key field for now).
final class YouTubeService {
    static let shared = YouTubeService()
    private init() {}

    struct YouTubeResult {
        let title: String
        let videoURL: String
        let thumbnailURL: String?
        let channelName: String
        let publishedAt: Date
    }

    /// Search YouTube for lectures/talks matching `query`.
    /// Set `apiKey` to a valid YouTube Data API v3 key.
    func search(query: String, apiKey: String?, maxResults: Int = 5) async throws -> [YouTubeResult] {
        guard let apiKey, !apiKey.isEmpty else { return [] }

        let academicQuery = "\(query) lecture OR conference talk OR keynote"
        let encoded = academicQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query

        let urlString = "https://www.googleapis.com/youtube/v3/search"
            + "?part=snippet&type=video&order=date&maxResults=\(maxResults)"
            + "&q=\(encoded)&key=\(apiKey)"
            + "&publishedAfter=\(iso8601DaysAgo(1))"

        guard let url = URL(string: urlString) else { return [] }

        let (data, _) = try await URLSession.shared.data(from: url)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["items"] as? [[String: Any]] else { return [] }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        return items.compactMap { item -> YouTubeResult? in
            guard let id = (item["id"] as? [String: Any])?["videoId"] as? String,
                  let snippet = item["snippet"] as? [String: Any],
                  let title = snippet["title"] as? String,
                  let channel = snippet["channelTitle"] as? String,
                  let pubStr = snippet["publishedAt"] as? String else { return nil }

            let thumb = ((snippet["thumbnails"] as? [String: Any])?["high"] as? [String: Any])?["url"] as? String

            return YouTubeResult(
                title: title,
                videoURL: "https://www.youtube.com/watch?v=\(id)",
                thumbnailURL: thumb,
                channelName: channel,
                publishedAt: formatter.date(from: pubStr) ?? Date()
            )
        }
    }

    private func iso8601DaysAgo(_ days: Int) -> String {
        let date = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.string(from: date)
    }
}
