import Foundation

/// Queries the arXiv Atom API for recent research papers matching given tags.
final class ArXivService {
    static let shared = ArXivService()
    private init() {}

    struct ArXivResult {
        let title: String
        let url: String
        let summary: String
        let authors: [String]
        let published: Date
    }

    /// Search arXiv for papers matching `query`, returning up to `maxResults` items.
    func search(query: String, maxResults: Int = 10) async throws -> [ArXivResult] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "https://export.arxiv.org/api/query?search_query=all:\(encoded)&start=0&max_results=\(maxResults)&sortBy=submittedDate&sortOrder=descending"

        guard let url = URL(string: urlString) else { return [] }

        let (data, _) = try await URLSession.shared.data(from: url)
        let parser = ArXivXMLParser(data: data)
        return parser.parse()
    }
}

// MARK: - Atom XML Parser

private final class ArXivXMLParser: NSObject, XMLParserDelegate {
    private let data: Data
    private var results: [ArXivService.ArXivResult] = []

    // Parsing state
    private var currentElement = ""
    private var currentTitle = ""
    private var currentLink = ""
    private var currentSummary = ""
    private var currentAuthor = ""
    private var currentPublished = ""
    private var currentAuthors: [String] = []
    private var insideEntry = false
    private var insideAuthor = false

    private let dateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    init(data: Data) {
        self.data = data
    }

    func parse() -> [ArXivService.ArXivResult] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return results
    }

    // MARK: XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName: String?,
                attributes: [String: String] = [:]) {
        currentElement = elementName

        if elementName == "entry" {
            insideEntry = true
            currentTitle = ""
            currentLink = ""
            currentSummary = ""
            currentAuthors = []
            currentPublished = ""
        }

        if insideEntry && elementName == "link" {
            if attributes["type"] == "text/html" || (attributes["rel"] == "alternate") {
                currentLink = attributes["href"] ?? ""
            }
        }

        if insideEntry && elementName == "author" {
            insideAuthor = true
            currentAuthor = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard insideEntry else { return }
        switch currentElement {
        case "title": currentTitle += string
        case "summary": currentSummary += string
        case "published": currentPublished += string
        case "name" where insideAuthor: currentAuthor += string
        default: break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName: String?) {
        if elementName == "author" {
            insideAuthor = false
            let name = currentAuthor.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty { currentAuthors.append(name) }
        }

        if elementName == "entry" {
            insideEntry = false
            let title = currentTitle
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "  ", with: " ")
            let summary = currentSummary
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "  ", with: " ")
            let date = dateFormatter.date(from: currentPublished.trimmingCharacters(in: .whitespacesAndNewlines)) ?? Date()

            results.append(ArXivService.ArXivResult(
                title: title,
                url: currentLink,
                summary: summary,
                authors: currentAuthors,
                published: date
            ))
        }

        currentElement = ""
    }
}
