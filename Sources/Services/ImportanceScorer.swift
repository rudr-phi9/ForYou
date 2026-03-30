import Foundation

/// Computes importance scores for research items based on author credibility
/// and content quality signals.
final class ImportanceScorer {
    static let shared = ImportanceScorer()
    private init() {}

    struct ScoringResult {
        let score: Double          // 0.0 to 10.0
        let authorMetric: String   // e.g. "Avg h-index: 42"
    }

    // MARK: - Score a Research Item

    /// Compute an importance score using Gemini to assess:
    /// - Author h-index / credibility (for papers)
    /// - Content quality and relevance to the tag
    func score(
        title: String,
        sourceType: ContentType,
        authors: [String],
        textSnippet: String,
        tagName: String
    ) async -> ScoringResult {
        let gemini = GeminiService.shared
        guard gemini.isConfigured else {
            return ScoringResult(score: 5.0, authorMetric: "Unscored")
        }

        let prompt: String
        switch sourceType {
        case .paper:
            prompt = """
            You are an academic research evaluator. Given the following research paper details, \
            estimate an importance score from 1 to 10 based on:
            1. The likely h-index of the authors (estimate from name recognition in the field).
            2. The relevance and novelty of the topic to "\(tagName)".
            3. The quality signals from the title and abstract.

            Title: \(title)
            Authors: \(authors.joined(separator: ", "))
            Abstract snippet: \(String(textSnippet.prefix(1500)))

            Respond in EXACTLY this format (no other text):
            SCORE: <number 1-10>
            AUTHORS: <brief assessment, e.g. "Avg estimated h-index: 35, well-known group">
            """
        case .blog:
            prompt = """
            You are a technical content evaluator. Rate this blog post/article from 1 to 10 based on:
            1. The credibility of the author/source.
            2. Technical depth and relevance to "\(tagName)".
            3. Whether it provides actionable insights or novel information.

            Title: \(title)
            Source/Author: \(authors.isEmpty ? "Unknown" : authors.joined(separator: ", "))
            Content snippet: \(String(textSnippet.prefix(1500)))

            Respond in EXACTLY this format (no other text):
            SCORE: <number 1-10>
            AUTHORS: <brief credibility assessment>
            """
        default:
            prompt = """
            Rate this content from 1 to 10 for research importance related to "\(tagName)".

            Title: \(title)
            Content snippet: \(String(textSnippet.prefix(1000)))

            Respond in EXACTLY this format (no other text):
            SCORE: <number 1-10>
            AUTHORS: <brief assessment>
            """
        }

        do {
            let response = try await gemini.generateRaw(prompt: prompt)
            return parseScoring(response)
        } catch {
            print("[Scorer] Error: \(error.localizedDescription)")
            return ScoringResult(score: 5.0, authorMetric: "Scoring unavailable")
        }
    }

    // MARK: - Parse

    private func parseScoring(_ raw: String) -> ScoringResult {
        var score = 5.0
        var authorMetric = ""

        for line in raw.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.uppercased().hasPrefix("SCORE:") {
                let numStr = trimmed.dropFirst(6).trimmingCharacters(in: .whitespacesAndNewlines)
                if let parsed = Double(numStr.prefix(while: { $0.isNumber || $0 == "." })) {
                    score = min(10, max(0, parsed))
                }
            }
            if trimmed.uppercased().hasPrefix("AUTHORS:") {
                authorMetric = String(trimmed.dropFirst(8)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return ScoringResult(score: score, authorMetric: authorMetric.isEmpty ? "Assessed" : authorMetric)
    }
}
