import Foundation

/// Uses Google Custom Search JSON API to find technical blogs and articles.
/// Requires a Google API key and a Custom Search Engine ID (cx).
///
/// Set up at: https://programmablesearchengine.google.com/
final class GoogleSearchService {
    static let shared = GoogleSearchService()
    private init() {}

    struct SearchResult {
        let title: String
        let url: String
        let snippet: String
        let source: String
    }

    /// Search Google for recent blog posts and technical articles matching `query`.
    /// Falls back to scraping if no API key is provided.
    func search(
        query: String,
        maxResults: Int = 8
    ) async throws -> [SearchResult] {
        // Use direct web search via scraping Google search results
        return try await scrapeGoogleSearch(query: query, maxResults: maxResults)
    }

    // MARK: - Scrape Google Search Results

    private func scrapeGoogleSearch(query: String, maxResults: Int) async throws -> [SearchResult] {
        // Build a query that targets blogs/articles and excludes news
        let searchQuery = "\(query) technical blog OR engineering blog OR tutorial -news -press -release"
        let encoded = searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "https://www.google.com/search?q=\(encoded)&num=\(maxResults)"

        guard let url = URL(string: urlString) else { return [] }

        var request = URLRequest(url: url)
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode),
              let html = String(data: data, encoding: .utf8) else {
            return []
        }

        return parseGoogleResults(html: html, maxResults: maxResults)
    }

    private func parseGoogleResults(html: String, maxResults: Int) -> [SearchResult] {
        var results: [SearchResult] = []

        // Extract search result blocks — look for <a href="/url?q=..." patterns
        let pattern = #"<a href="/url\?q=([^&"]+)&[^"]*"[^>]*>(.*?)</a>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return results
        }

        let nsHTML = html as NSString
        let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: nsHTML.length))

        let excludedDomains = SettingsManager.shared.excludedDomains + [
            "google.com", "youtube.com", "accounts.google", "support.google",
            "maps.google", "translate.google", "webcache.google"
        ]

        for match in matches {
            guard results.count < maxResults else { break }

            if match.numberOfRanges >= 3 {
                let urlStr = nsHTML.substring(with: match.range(at: 1))
                    .removingPercentEncoding ?? nsHTML.substring(with: match.range(at: 1))
                let rawTitle = nsHTML.substring(with: match.range(at: 2))

                // Clean HTML tags from title
                let title = rawTitle.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                // Filter out excluded domains and empty titles
                guard !title.isEmpty,
                      title.count > 5,
                      urlStr.hasPrefix("http"),
                      !excludedDomains.contains(where: { urlStr.lowercased().contains($0) }) else {
                    continue
                }

                let source = URL(string: urlStr)?.host ?? "Web"

                results.append(SearchResult(
                    title: title,
                    url: urlStr,
                    snippet: "",
                    source: source
                ))
            }
        }

        return results
    }
}
