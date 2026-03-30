import Foundation

/// Searches for technical blogs and articles using DuckDuckGo HTML (no API key needed).
final class GoogleSearchService {
    static let shared = GoogleSearchService()
    private init() {}

    struct SearchResult {
        let title: String
        let url: String
        let snippet: String
        let source: String
    }

    /// Search for recent blog posts and technical articles matching `query`.
    func search(
        query: String,
        maxResults: Int = 8
    ) async throws -> [SearchResult] {
        print("[BlogSearch] Searching DuckDuckGo for '\(query)'...")
        let results = try await scrapeDuckDuckGo(query: query, maxResults: maxResults)
        print("[BlogSearch] DuckDuckGo returned \(results.count) results for '\(query)'")
        return results
    }

    // MARK: - DuckDuckGo HTML Scraper

    private func scrapeDuckDuckGo(query: String, maxResults: Int) async throws -> [SearchResult] {
        let searchQuery = "\(query) blog OR tutorial OR guide"
        let encoded = searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "https://html.duckduckgo.com/html/?q=\(encoded)"

        guard let url = URL(string: urlString) else { return [] }

        var request = URLRequest(url: url)
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("text/html", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode),
              let html = String(data: data, encoding: .utf8) else {
            print("[BlogSearch] DuckDuckGo HTTP error or empty response")
            return []
        }

        return parseDuckDuckGoResults(html: html, maxResults: maxResults)
    }

    private func parseDuckDuckGoResults(html: String, maxResults: Int) -> [SearchResult] {
        var results: [SearchResult] = []

        // DuckDuckGo HTML results use class="result__a" for links and class="result__snippet" for snippets
        // Pattern: <a rel="nofollow" class="result__a" href="URL">TITLE</a>
        let linkPattern = #"class="result__a"[^>]*href="([^"]+)"[^>]*>(.*?)</a>"#
        let snippetPattern = #"class="result__snippet"[^>]*>(.*?)</(?:td|div|span)>"#

        guard let linkRegex = try? NSRegularExpression(pattern: linkPattern, options: [.dotMatchesLineSeparators]),
              let snippetRegex = try? NSRegularExpression(pattern: snippetPattern, options: [.dotMatchesLineSeparators]) else {
            return results
        }

        let nsHTML = html as NSString
        let linkMatches = linkRegex.matches(in: html, options: [], range: NSRange(location: 0, length: nsHTML.length))
        let snippetMatches = snippetRegex.matches(in: html, options: [], range: NSRange(location: 0, length: nsHTML.length))

        let excludedDomains = SettingsManager.shared.excludedDomains + [
            "duckduckgo.com", "youtube.com", "google.com", "facebook.com", "twitter.com",
            "reddit.com", "instagram.com", "tiktok.com"
        ]

        for (i, match) in linkMatches.enumerated() {
            guard results.count < maxResults else { break }
            guard match.numberOfRanges >= 3 else { continue }

            var urlStr = nsHTML.substring(with: match.range(at: 1))

            // DuckDuckGo sometimes wraps URLs in a redirect, extract the actual URL
            if urlStr.contains("uddg="), let components = URLComponents(string: urlStr),
               let actualURL = components.queryItems?.first(where: { $0.name == "uddg" })?.value {
                urlStr = actualURL
            }

            let rawTitle = nsHTML.substring(with: match.range(at: 2))
            let title = rawTitle.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "&amp;", with: "&")
                .replacingOccurrences(of: "&lt;", with: "<")
                .replacingOccurrences(of: "&gt;", with: ">")
                .replacingOccurrences(of: "&#x27;", with: "'")
                .replacingOccurrences(of: "&quot;", with: "\"")

            guard !title.isEmpty,
                  title.count > 5,
                  urlStr.hasPrefix("http"),
                  !excludedDomains.contains(where: { urlStr.lowercased().contains($0) }) else {
                continue
            }

            // Get snippet if available
            var snippet = ""
            if i < snippetMatches.count, snippetMatches[i].numberOfRanges >= 2 {
                snippet = nsHTML.substring(with: snippetMatches[i].range(at: 1))
                    .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "&amp;", with: "&")
                    .replacingOccurrences(of: "&lt;", with: "<")
                    .replacingOccurrences(of: "&gt;", with: ">")
            }

            let source = URL(string: urlStr)?.host ?? "Web"

            results.append(SearchResult(
                title: title,
                url: urlStr,
                snippet: snippet,
                source: source
            ))
        }

        return results
    }
}
