import Foundation

/// Lightweight web scraper for fetching page text and metadata.
/// Used for technical blogs and as a fallback text extractor.
final class WebScraperService {
    static let shared = WebScraperService()
    private init() {}

    struct ScrapedPage {
        let title: String
        let textContent: String
        let heroImageURL: String?
    }

    /// Fetch a URL and extract readable text content from HTML.
    func scrape(url: URL) async throws -> ScrapedPage {
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode),
              let html = String(data: data, encoding: .utf8) else {
            throw ScraperError.fetchFailed
        }

        let title = extractTitle(from: html)
        let textContent = extractText(from: html)
        let heroImage = extractHeroImage(from: html, baseURL: url)

        return ScrapedPage(
            title: title,
            textContent: textContent,
            heroImageURL: heroImage
        )
    }

    // MARK: - HTML Extraction (regex-based, lightweight)

    private func extractTitle(from html: String) -> String {
        if let range = html.range(of: "(?<=<title>)(.+?)(?=</title>)", options: .regularExpression) {
            return String(html[range])
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "&amp;", with: "&")
                .replacingOccurrences(of: "&#39;", with: "'")
                .replacingOccurrences(of: "&quot;", with: "\"")
        }
        return "Untitled"
    }

    private func extractText(from html: String) -> String {
        var text = html
        // Remove scripts and styles
        text = text.replacingOccurrences(
            of: "<script[^>]*>[\\s\\S]*?</script>",
            with: " ", options: .regularExpression
        )
        text = text.replacingOccurrences(
            of: "<style[^>]*>[\\s\\S]*?</style>",
            with: " ", options: .regularExpression
        )
        // Remove HTML tags
        text = text.replacingOccurrences(
            of: "<[^>]+>",
            with: " ", options: .regularExpression
        )
        // Decode common entities
        text = text.replacingOccurrences(of: "&nbsp;", with: " ")
        text = text.replacingOccurrences(of: "&amp;", with: "&")
        text = text.replacingOccurrences(of: "&lt;", with: "<")
        text = text.replacingOccurrences(of: "&gt;", with: ">")
        text = text.replacingOccurrences(of: "&#39;", with: "'")
        text = text.replacingOccurrences(of: "&quot;", with: "\"")
        // Compress whitespace
        text = text.replacingOccurrences(
            of: "\\s+", with: " ", options: .regularExpression
        )
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractHeroImage(from html: String, baseURL: URL) -> String? {
        // Try og:image first
        if let range = html.range(
            of: "(?<=property=\"og:image\"\\s{0,5}content=\")[^\"]+",
            options: .regularExpression
        ) {
            return String(html[range])
        }
        // Try first large image
        if let range = html.range(
            of: "(?<=<img[^>]*src=\")[^\"]+",
            options: .regularExpression
        ) {
            let src = String(html[range])
            if src.hasPrefix("http") { return src }
            return baseURL.scheme.map { "\($0)://\(baseURL.host ?? "")\(src)" }
        }
        return nil
    }

    enum ScraperError: LocalizedError {
        case fetchFailed
        var errorDescription: String? { "Failed to fetch web page." }
    }
}
