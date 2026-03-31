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
        guard let apiKey, !apiKey.isEmpty else {
            print("[YouTube] No API key provided, skipping")
            return []
        }

        let academicQuery = "\(query) lecture OR conference talk OR keynote"

        // Build URL with properly encoded components
        var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/search")!
        components.queryItems = [
            URLQueryItem(name: "part", value: "snippet"),
            URLQueryItem(name: "type", value: "video"),
            URLQueryItem(name: "order", value: "date"),
            URLQueryItem(name: "maxResults", value: "\(maxResults)"),
            URLQueryItem(name: "q", value: academicQuery),
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "publishedAfter", value: iso8601DaysAgo(7)),
        ]

        guard let url = components.url else {
            print("[YouTube] Failed to construct URL")
            return []
        }

        print("[YouTube] Requesting: \(academicQuery)")
        let (data, response) = try await URLSession.shared.data(from: url)

        // Log HTTP status
        if let httpResponse = response as? HTTPURLResponse {
            print("[YouTube] HTTP status: \(httpResponse.statusCode)")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("[YouTube] Failed to parse JSON response")
            return []
        }

        // Check for API error response
        if let error = json["error"] as? [String: Any] {
            let code = error["code"] as? Int ?? -1
            let message = error["message"] as? String ?? "Unknown error"
            print("[YouTube] API ERROR (\(code)): \(message)")
            return []
        }

        guard let items = json["items"] as? [[String: Any]] else {
            print("[YouTube] No 'items' key in response. Keys: \(json.keys.joined(separator: ", "))")
            return []
        }

        print("[YouTube] Got \(items.count) results")

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
