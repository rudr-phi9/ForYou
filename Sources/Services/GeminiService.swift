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
            name: "gemini-2.5-pro",
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

        let truncated = String(fullText.prefix(28_000)) // stay under token limits

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
