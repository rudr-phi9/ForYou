import Foundation
import GoogleGenerativeAI

/// Wrapper around the Google Generative AI SDK (Gemini 1.5 Pro).
final class GeminiService {
    static let shared = GeminiService()

    private var model: GenerativeModel?

    private init() {}

    // MARK: - Configuration

    /// Reconfigure the model whenever the API key changes.
    func configure(apiKey: String) {
        guard !apiKey.isEmpty else {
            model = nil
            return
        }
        model = GenerativeModel(
            name: "gemini-2.5-flash-lite",
            apiKey: apiKey
        )
    }

    var isConfigured: Bool { model != nil }

    // MARK: - Content Classification (NEWS vs RESEARCH)

    /// Returns `true` if the content qualifies as research / technical,
    /// `false` if it is a general news article or press release.
    func classifyContent(title: String, url: String, snippet: String?) async throws -> Bool {
        guard let model else { throw GeminiError.notConfigured }

        let prompt = """
        You are a strict content classifier. Determine whether the following item is a \
        general news article or press release (NEWS), or whether it is a research paper, \
        technical/engineering blog post, or academic conference talk (RESEARCH).

        Title: \(title)
        URL: \(url)
        \(snippet.map { "Snippet: \($0)" } ?? "")

        Respond with exactly one word: NEWS or RESEARCH
        """

        let response = try await model.generateContent(prompt)
        let answer = (response.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return answer != "NEWS"
    }

    // MARK: - Raw Prompt

    /// Send an arbitrary prompt and return the raw text response.
    func generateRaw(prompt: String) async throws -> String {
        guard let model else { throw GeminiError.notConfigured }
        let response = try await model.generateContent(prompt)
        guard let text = response.text, !text.isEmpty else {
            throw GeminiError.emptyResponse
        }
        return text
    }

    // MARK: - Summarisation (Text)

    struct Summary {
        let text: String
        let keyTakeaways: [String]
    }

    /// Generate a Gemini summary for textual content (paper, blog).
    func summariseText(
        title: String,
        contentType: ContentType,
        fullText: String
    ) async throws -> Summary {
        guard let model else { throw GeminiError.notConfigured }

        let truncated = String(fullText.prefix(6_000)) // reduced from 28k to save tokens

        let prompt: String
        switch contentType {
        case .paper:
            prompt = """
            You are a research assistant for a doctoral researcher. Summarise the following \
            research paper in exactly 4 sentences, then list exactly 3 key takeaways as bullet \
            points prefixed with "•".

            Title: \(title)

            Full Text:
            \(truncated)

            Format your response as:
            SUMMARY:
            <4 sentence summary>

            KEY TAKEAWAYS:
            • <takeaway 1>
            • <takeaway 2>
            • <takeaway 3>
            """
        case .talk:
            prompt = """
            You are a research assistant. Summarise this lecture/talk in 4 sentences covering \
            the visual findings and main narrative, highlighting key moments. Then list 3 key \
            takeaways prefixed with "•".

            Title: \(title)

            Content:
            \(truncated)

            Format your response as:
            SUMMARY:
            <4 sentence summary>

            KEY TAKEAWAYS:
            • <takeaway 1>
            • <takeaway 2>
            • <takeaway 3>
            """
        default:
            prompt = """
            You are a research assistant for a doctoral researcher. Provide a concise 4-sentence \
            summary of this technical blog/article, then list 3 key takeaways prefixed with "•".

            Title: \(title)

            Content:
            \(truncated)

            Format your response as:
            SUMMARY:
            <4 sentence summary>

            KEY TAKEAWAYS:
            • <takeaway 1>
            • <takeaway 2>
            • <takeaway 3>
            """
        }

        let response = try await model.generateContent(prompt)
        return parseResponse(response.text ?? "")
    }

    // MARK: - Multimodal Image Analysis (Fallback)

    /// Send a screenshot image to Gemini when direct text fetch fails (paywall fallback).
    func summariseImage(
        title: String,
        imageData: Data,
        mimeType: String = "image/png"
    ) async throws -> Summary {
        guard let model else { throw GeminiError.notConfigured }

        let prompt = """
        You are a research assistant. This is a screenshot of a research article or paper. \
        Provide a 4-sentence summary and 3 key takeaways.

        Title: \(title)

        Format your response as:
        SUMMARY:
        <4 sentence summary>

        KEY TAKEAWAYS:
        • <takeaway 1>
        • <takeaway 2>
        • <takeaway 3>
        """

        let imagePart = ModelContent.Part.data(mimetype: mimeType, imageData)
        let textPart = ModelContent.Part.text(prompt)
        let content = [ModelContent(role: "user", parts: [textPart, imagePart])]

        let response = try await model.generateContent(content)
        return parseResponse(response.text ?? "")
    }

    // MARK: - Parsing

    private func parseResponse(_ raw: String) -> Summary {
        var summaryText = ""
        var takeaways: [String] = []

        let lines = raw.components(separatedBy: "\n")
        var inSummary = false
        var inTakeaways = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.uppercased().hasPrefix("SUMMARY") {
                inSummary = true
                inTakeaways = false
                continue
            }
            if trimmed.uppercased().hasPrefix("KEY TAKEAWAY") {
                inSummary = false
                inTakeaways = true
                continue
            }
            if inSummary && !trimmed.isEmpty {
                summaryText += (summaryText.isEmpty ? "" : " ") + trimmed
            }
            if inTakeaways && trimmed.hasPrefix("•") {
                let cleaned = trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
                if !cleaned.isEmpty { takeaways.append(cleaned) }
            }
        }

        if summaryText.isEmpty { summaryText = raw }

        return Summary(text: summaryText, keyTakeaways: takeaways)
    }

    // MARK: - Combined Enrich (summary + score in ONE API call)

    struct EnrichedResult {
        let summary: Summary
        let importanceScore: Double
        let authorMetric: String
        let isHighQuality: Bool
    }

    /// Single API call that returns summary, key takeaways, importance score, and author metric.
    /// Use this instead of separate summariseText + ImportanceScorer.score calls to halve costs.
    func enrichContent(
        title: String,
        contentType: ContentType,
        fullText: String,
        authors: [String],
        tagName: String
    ) async throws -> EnrichedResult {
        guard let model else { throw GeminiError.notConfigured }

        let truncated = String(fullText.prefix(6_000))
        let authorLine = authors.isEmpty ? "Unknown" : authors.joined(separator: ", ")

        let typeLabel: String
        switch contentType {
        case .paper: typeLabel = "research paper"
        case .blog:  typeLabel = "technical blog post"
        case .talk:  typeLabel = "lecture/conference talk"
        default:     typeLabel = "article"
        }

        let prompt = """
        You are a research assistant evaluating content for a researcher interested in "\(tagName)".

        Analyze this \(typeLabel):
        Title: \(title)
        Authors/Source: \(authorLine)
        Content:
        \(truncated)

        First, assess content quality. Mark as LOW quality if the content is any of:
        - Memes, jokes, satire, entertainment, or clickbait
        - Kids material, cartoons and comics
        - Listicles, "top N" roundups, or superficial overviews
        - Content aimed at beginners/children with no technical depth
        - Promotional material, press releases, or marketing
        - Unrelated to serious research, engineering, or technical discussion

        Respond in EXACTLY this format (no extra text):
        QUALITY: <HIGH or LOW>

        SUMMARY:
        <4-sentence summary>

        KEY TAKEAWAYS:
        • <takeaway 1>
        • <takeaway 2>
        • <takeaway 3>

        SCORE: <integer 1-10>
        AUTHORS: <one-line credibility note, e.g. "Well-known group, est. h-index 35" or "Independent blogger">
        """

        let response = try await model.generateContent(prompt)
        let raw = response.text ?? ""
        return parseEnrichedResponse(raw)
    }

    private func parseEnrichedResponse(_ raw: String) -> EnrichedResult {
        var summaryText = ""
        var takeaways: [String] = []
        var score = 5.0
        var authorMetric = ""
        var isHighQuality = true

        let lines = raw.components(separatedBy: "\n")
        var inSummary = false
        var inTakeaways = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.uppercased().hasPrefix("QUALITY:") {
                let val = trimmed.dropFirst(8).trimmingCharacters(in: .whitespaces).uppercased()
                isHighQuality = val != "LOW"
                continue
            }
            if trimmed.uppercased().hasPrefix("SUMMARY") { inSummary = true; inTakeaways = false; continue }
            if trimmed.uppercased().hasPrefix("KEY TAKEAWAY") { inSummary = false; inTakeaways = true; continue }
            if trimmed.uppercased().hasPrefix("SCORE:") {
                inSummary = false; inTakeaways = false
                let numStr = trimmed.dropFirst(6).trimmingCharacters(in: .whitespaces)
                if let parsed = Double(numStr.prefix(while: { $0.isNumber || $0 == "." })) {
                    score = min(10, max(0, parsed))
                }
                continue
            }
            if trimmed.uppercased().hasPrefix("AUTHORS:") {
                inSummary = false; inTakeaways = false
                authorMetric = String(trimmed.dropFirst(8)).trimmingCharacters(in: .whitespaces)
                continue
            }
            if inSummary && !trimmed.isEmpty {
                summaryText += (summaryText.isEmpty ? "" : " ") + trimmed
            }
            if inTakeaways && trimmed.hasPrefix("•") {
                let cleaned = trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
                if !cleaned.isEmpty { takeaways.append(cleaned) }
            }
        }

        if summaryText.isEmpty { summaryText = raw }
        let summary = Summary(text: summaryText, keyTakeaways: takeaways)
        return EnrichedResult(summary: summary, importanceScore: score, authorMetric: authorMetric, isHighQuality: isHighQuality)
    }

    // MARK: - Chat About Item

    /// Multi-turn chat grounded in a research item's context.
    /// Sends the item summary + content as system context, chat history, and the new user question.
    func chat(
        itemTitle: String,
        itemSummary: String?,
        itemTakeaways: [String],
        itemContent: String?,
        history: [(role: String, content: String)],
        userMessage: String
    ) async throws -> String {
        guard let model else { throw GeminiError.notConfigured }

        var parts: [String] = []
        parts.append("""
        You are an expert research assistant with deep knowledge across all scientific and technical domains. \
        The user is asking about a specific research item. You have been given context about this item below.

        INSTRUCTIONS:
        - Answer questions thoroughly and in detail, combining the provided context with your own knowledge.
        - If the provided content is a summary, expand on the topic using your training knowledge.
        - Explain concepts, methods, results, and implications in depth when asked.
        - Use markdown formatting: **bold** for emphasis, bullet points for lists, code blocks for code.
        - If the user asks for more detail, provide a comprehensive explanation — never refuse by saying you only have a summary.
        - Be conversational and helpful, like a knowledgeable colleague.

        TITLE: \(itemTitle)
        """)

        if let summary = itemSummary, !summary.isEmpty {
            parts.append("SUMMARY: \(summary)")
        }
        if !itemTakeaways.isEmpty {
            parts.append("KEY TAKEAWAYS:\n" + itemTakeaways.map { "• \($0)" }.joined(separator: "\n"))
        }
        if let content = itemContent, !content.isEmpty {
            parts.append("FULL CONTENT:\n\(String(content.prefix(8_000)))")
        }

        parts.append("---\nCONVERSATION:")
        for msg in history {
            parts.append("\(msg.role == "user" ? "User" : "Assistant"): \(msg.content)")
        }
        parts.append("User: \(userMessage)")
        parts.append("\nAssistant:")

        let prompt = parts.joined(separator: "\n\n")
        let response = try await model.generateContent(prompt)
        guard let text = response.text, !text.isEmpty else {
            throw GeminiError.emptyResponse
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Errors

    enum GeminiError: LocalizedError {
        case notConfigured
        case emptyResponse

        var errorDescription: String? {
            switch self {
            case .notConfigured: return "Gemini API key not configured."
            case .emptyResponse: return "Gemini returned an empty response."
            }
        }
    }
}
