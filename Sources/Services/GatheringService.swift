import Foundation
import SwiftData

/// Background service that periodically gathers research content,
/// filters it through Gemini, and triggers notifications.
final class GatheringService {
    static let shared = GatheringService()

    private var backgroundTask: Task<Void, Never>?
    private var modelContainer: ModelContainer?

    private init() {}

    // MARK: - Lifecycle

    func start(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        startBackgroundLoop()
    }

    func stop() {
        backgroundTask?.cancel()
        backgroundTask = nil
    }

    private func startBackgroundLoop() {
        backgroundTask?.cancel()
        backgroundTask = Task { [weak self] in
            // Initial short delay to let app settle
            try? await Task.sleep(for: .seconds(10))

            while !Task.isCancelled {
                await self?.performGathering()
                let interval = SettingsManager.shared.syncIntervalSeconds
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    // MARK: - Manual Trigger

    @MainActor
    func syncNow(appState: AppState) async {
        guard !appState.isSyncing else { return }
        appState.isSyncing = true
        await performGathering()
        appState.isSyncing = false
        appState.lastSyncDate = Date()
    }

    // MARK: - Core Gathering Logic

    func performGathering() async {
        guard let modelContainer else {
            print("[Gathering] No model container set.")
            return
        }

        print("[Gathering] Starting sync at \(Date())")

        let context = ModelContext(modelContainer)

        // 1. Read active tags
        let tagDescriptor = FetchDescriptor<Tag>(predicate: #Predicate { $0.isActive })
        guard let tags = try? context.fetch(tagDescriptor), !tags.isEmpty else {
            print("[Gathering] No active tags found.")
            return
        }

        let gemini = GeminiService.shared
        let settings = SettingsManager.shared

        // Configure Gemini if needed
        if !gemini.isConfigured && settings.hasAPIKey {
            gemini.configure(apiKey: settings.geminiAPIKey)
        }

        for tag in tags {
            await gatherForTag(tag, context: context, gemini: gemini)
        }

        try? context.save()
        SettingsManager.shared.lastSyncDate = Date()
        print("[Gathering] Sync complete at \(Date())")
    }

    // MARK: - Per-Tag Gathering

    private func gatherForTag(_ tag: Tag, context: ModelContext, gemini: GeminiService) async {
        // --- arXiv Papers ---
        await gatherArXiv(tag: tag, context: context, gemini: gemini)

        // --- Google Search: Blogs & Articles ---
        await gatherBlogs(tag: tag, context: context, gemini: gemini)

        // --- YouTube Talks (if YouTube API key available) ---
        await gatherYouTube(tag: tag, context: context, gemini: gemini)
    }

    // MARK: - arXiv

    private func gatherArXiv(tag: Tag, context: ModelContext, gemini: GeminiService) async {
        do {
            let results = try await ArXivService.shared.search(query: tag.name, maxResults: 8)

            for result in results {
                // Check for duplicates
                let url = result.url
                let descriptor = FetchDescriptor<ResearchItem>(
                    predicate: #Predicate { $0.url == url }
                )
                if let existing = try? context.fetch(descriptor), !existing.isEmpty {
                    continue
                }

                // Domain exclusion check
                if isExcludedDomain(url: result.url) { continue }

                let item = ResearchItem(
                    title: result.title,
                    url: result.url,
                    sourceType: .paper,
                    sourceName: "arXiv",
                    tagNames: [tag.name]
                )
                item.rawTextContent = result.summary
                item.timestamp = result.published
                item.authors = result.authors

                // AI classification filter
                if gemini.isConfigured {
                    if let isResearch = try? await gemini.classifyContent(
                        title: result.title, url: result.url, snippet: result.summary
                    ), !isResearch {
                        item.isDiscarded = true
                        continue
                    }

                    // Summarise immediately
                    await summariseItem(item, gemini: gemini)

                    // Compute importance score
                    await scoreItem(item, tagName: tag.name)
                }

                context.insert(item)

                // Notify user
                if item.isSummarized, let summary = item.geminiSummary {
                    let firstSentence = summary.components(separatedBy: ". ").first ?? summary
                    NotificationService.shared.notifyNewContent(
                        itemId: item.id,
                        tagName: tag.name,
                        title: item.title,
                        summaryFirstSentence: firstSentence
                    )
                }
            }
        } catch {
            print("[Gathering] arXiv error for '\(tag.name)': \(error.localizedDescription)")
        }
    }

    // MARK: - YouTube

    private func gatherYouTube(tag: Tag, context: ModelContext, gemini: GeminiService) async {
        do {
            // YouTube requires its own API key. For now, reuse the Gemini settings
            // or set a dedicated YouTube key. Placeholder — skips if no key.
            let results = try await YouTubeService.shared.search(
                query: tag.name,
                apiKey: nil, // TODO: Add YouTube Data API v3 key support
                maxResults: 3
            )

            for result in results {
                let url = result.videoURL
                let descriptor = FetchDescriptor<ResearchItem>(
                    predicate: #Predicate { $0.url == url }
                )
                if let existing = try? context.fetch(descriptor), !existing.isEmpty {
                    continue
                }

                let item = ResearchItem(
                    title: result.title,
                    url: result.videoURL,
                    sourceType: .talk,
                    sourceName: result.channelName,
                    tagNames: [tag.name]
                )
                item.thumbnailURL = result.thumbnailURL
                item.timestamp = result.publishedAt

                context.insert(item)
            }
        } catch {
            print("[Gathering] YouTube error for '\(tag.name)': \(error.localizedDescription)")
        }
    }

    // MARK: - Summarisation

    func summariseItem(_ item: ResearchItem, gemini: GeminiService) async {
        guard !item.isSummarized, !item.isDiscarded else { return }

        // Try text-based summary first
        var textContent = item.rawTextContent ?? ""

        // If no raw text, scrape the URL
        if textContent.isEmpty, let url = item.sourceURL {
            do {
                let scraped = try await WebScraperService.shared.scrape(url: url)
                textContent = scraped.textContent
                if item.heroImageURL == nil {
                    item.heroImageURL = scraped.heroImageURL
                }
            } catch {
                print("[Gathering] Scrape failed for \(item.url): \(error.localizedDescription)")
            }
        }

        // Attempt Gemini summary
        do {
            if !textContent.isEmpty {
                let summary = try await gemini.summariseText(
                    title: item.title,
                    contentType: item.sourceType,
                    fullText: textContent
                )
                item.geminiSummary = summary.text
                item.keyTakeaways = summary.keyTakeaways
                item.isSummarized = true

                // Score if not yet scored
                if item.importanceScore == 0 {
                    await scoreItem(item, tagName: item.tagNames.first ?? "")
                }
            } else {
                // Fallback: screenshot analysis would go here.
                // For now, mark as unsummarized so it can be retried.
                print("[Gathering] No text content for \(item.title)")
            }
        } catch {
            print("[Gathering] Gemini summary error: \(error.localizedDescription)")
        }
    }

    /// Summarise all unsummarised items in the database.
    func summariseUnsummarised() async {
        guard let modelContainer else { return }

        let context = ModelContext(modelContainer)
        let gemini = GeminiService.shared

        let descriptor = FetchDescriptor<ResearchItem>(
            predicate: #Predicate { !$0.isSummarized && !$0.isDiscarded }
        )
        guard let items = try? context.fetch(descriptor) else { return }

        for item in items {
            await summariseItem(item, gemini: gemini)
        }

        try? context.save()
    }

    // MARK: - Domain Filter

    private func isExcludedDomain(url: String) -> Bool {
        let lowered = url.lowercased()
        return SettingsManager.shared.excludedDomains.contains { lowered.contains($0) }
    }

    // MARK: - Blogs & Articles (Google Search)

    private func gatherBlogs(tag: Tag, context: ModelContext, gemini: GeminiService) async {
        do {
            let results = try await GoogleSearchService.shared.search(query: tag.name, maxResults: 6)

            for result in results {
                let url = result.url
                let descriptor = FetchDescriptor<ResearchItem>(
                    predicate: #Predicate { $0.url == url }
                )
                if let existing = try? context.fetch(descriptor), !existing.isEmpty {
                    continue
                }

                if isExcludedDomain(url: result.url) { continue }

                let item = ResearchItem(
                    title: result.title,
                    url: result.url,
                    sourceType: .blog,
                    sourceName: result.source,
                    tagNames: [tag.name]
                )
                item.rawTextContent = result.snippet

                // AI classification filter
                if gemini.isConfigured {
                    if let isResearch = try? await gemini.classifyContent(
                        title: result.title, url: result.url, snippet: result.snippet
                    ), !isResearch {
                        item.isDiscarded = true
                        continue
                    }

                    await summariseItem(item, gemini: gemini)
                    await scoreItem(item, tagName: tag.name)
                }

                context.insert(item)

                if item.isSummarized, let summary = item.geminiSummary {
                    let firstSentence = summary.components(separatedBy: ". ").first ?? summary
                    NotificationService.shared.notifyNewContent(
                        itemId: item.id,
                        tagName: tag.name,
                        title: item.title,
                        summaryFirstSentence: firstSentence
                    )
                }
            }
        } catch {
            print("[Gathering] Blog search error for '\(tag.name)': \(error.localizedDescription)")
        }
    }

    // MARK: - Importance Scoring

    private func scoreItem(_ item: ResearchItem, tagName: String) async {
        let result = await ImportanceScorer.shared.score(
            title: item.title,
            sourceType: item.sourceType,
            authors: item.authors,
            textSnippet: item.rawTextContent ?? item.geminiSummary ?? "",
            tagName: tagName
        )
        item.importanceScore = result.score
        item.authorMetric = result.authorMetric
    }
}
