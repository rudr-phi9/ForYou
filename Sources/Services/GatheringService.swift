import Foundation
import SwiftData

/// Background service that periodically gathers research content,
/// filters it through Gemini, and triggers notifications.
final class GatheringService {
    static let shared = GatheringService()

    /// Max tags fetched in parallel to avoid overwhelming APIs.
    private let maxConcurrency = 10

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
        backgroundTask = Task { @MainActor [weak self] in
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

    // MARK: - Raw fetch results (value types for Sendable transfer)

    private struct FetchedItem: Sendable {
        let title: String
        let url: String
        let sourceType: ContentType
        let sourceName: String
        let rawText: String
        let authors: [String]
        let timestamp: Date
        let tagName: String
        let thumbnailURL: String?

        init(title: String, url: String, sourceType: ContentType, sourceName: String,
             rawText: String, authors: [String], timestamp: Date, tagName: String,
             thumbnailURL: String? = nil) {
            self.title = title
            self.url = url
            self.sourceType = sourceType
            self.sourceName = sourceName
            self.rawText = rawText
            self.authors = authors
            self.timestamp = timestamp
            self.tagName = tagName
            self.thumbnailURL = thumbnailURL
        }
    }

    // MARK: - Core Gathering Logic

    @MainActor
    func performGathering() async {
        guard let modelContainer else {
            print("[Gathering] No model container set.")
            return
        }

        let startTime = CFAbsoluteTimeGetCurrent()
        print("[Gathering] Starting sync at \(Date())")

        let context = modelContainer.mainContext

        // 1. Read active tags
        let tagDescriptor = FetchDescriptor<Tag>(predicate: #Predicate { $0.isActive })
        guard let tags = try? context.fetch(tagDescriptor), !tags.isEmpty else {
            print("[Gathering] No active tags found.")
            return
        }

        let tagNames = tags.map(\.name)
        print("[Gathering] Found \(tags.count) active tag(s): \(tagNames.joined(separator: ", "))")

        let gemini = GeminiService.shared
        let settings = SettingsManager.shared

        // Configure Gemini if needed
        if !gemini.isConfigured && settings.hasAPIKey {
            gemini.configure(apiKey: settings.geminiAPIKey)
        }
        print("[Gathering] Gemini configured: \(gemini.isConfigured)")

        // 2. Fetch all sources for all tags in parallel (network-only, no SwiftData)
        let allFetched = await fetchAllTagsInParallel(tagNames: tagNames)
        print("[Gathering] Fetched \(allFetched.count) total raw items across \(tagNames.count) tag(s)")

        // 3. Insert into SwiftData on main context (serial, deduped)
        var newItems: [ResearchItem] = []
        for fetched in allFetched {
            let url = fetched.url
            let descriptor = FetchDescriptor<ResearchItem>(
                predicate: #Predicate { $0.url == url }
            )
            if let existing = try? context.fetch(descriptor), !existing.isEmpty {
                continue
            }
            if isExcludedDomain(url: fetched.url) { continue }

            let item = ResearchItem(
                title: fetched.title,
                url: fetched.url,
                sourceType: fetched.sourceType,
                sourceName: fetched.sourceName,
                tagNames: [fetched.tagName]
            )
            item.rawTextContent = fetched.rawText
            item.timestamp = fetched.timestamp
            item.authors = fetched.authors
            item.thumbnailURL = fetched.thumbnailURL

            context.insert(item)
            newItems.append(item)
            print("[Gathering] Inserted: \(fetched.title.prefix(60))…")
        }

        try? context.save()
        print("[Gathering] Inserted \(newItems.count) new items into database")

        // 4. AI enrichment (summary + score in ONE API call via enrichContent)
        if gemini.isConfigured {
            for item in newItems {
                await summariseItem(item, gemini: gemini)
            }
            try? context.save()
        }

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        SettingsManager.shared.lastSyncDate = Date()
        print("[Gathering] Sync complete in \(String(format: "%.1f", elapsed))s — \(newItems.count) new items")
    }

    // MARK: - Parallel Fetching (network only, no SwiftData)

    /// Fetches arXiv + blogs for all tags concurrently, up to `maxConcurrency` at a time.
    private nonisolated func fetchAllTagsInParallel(tagNames: [String]) async -> [FetchedItem] {
        await withTaskGroup(of: [FetchedItem].self) { group in
            for (index, tagName) in tagNames.enumerated() {
                // Throttle: don't launch more than maxConcurrency at once
                if index >= maxConcurrency {
                    // Wait for one to finish before launching another
                    if let partial = await group.next() {
                        _ = partial // collected below via reduce
                    }
                }

                group.addTask { [self] in
                    await self.fetchForTag(tagName: tagName)
                }
            }

            // Collect all results
            var all: [FetchedItem] = []
            for await batch in group {
                all.append(contentsOf: batch)
            }
            return all
        }
    }

    /// Fetch arXiv + blogs + YouTube for a single tag (pure network, returns value types).
    private nonisolated func fetchForTag(tagName: String) async -> [FetchedItem] {
        // Run all source fetches in parallel for this tag
        async let arxivItems = fetchArXiv(tagName: tagName)
        async let blogItems = fetchBlogs(tagName: tagName)
        async let youtubeItems = fetchYouTube(tagName: tagName)

        let a = await arxivItems
        let b = await blogItems
        let c = await youtubeItems
        return a + b + c
    }

    /// Fetch arXiv papers — pure network, returns value-type results.
    private nonisolated func fetchArXiv(tagName: String) async -> [FetchedItem] {
        print("[Gathering] Fetching arXiv for '\(tagName)'...")
        do {
            let results = try await ArXivService.shared.search(query: tagName, maxResults: 8)
            print("[Gathering] arXiv returned \(results.count) results for '\(tagName)'")
            return results.map { r in
                FetchedItem(
                    title: r.title, url: r.url, sourceType: .paper,
                    sourceName: "arXiv", rawText: r.summary,
                    authors: r.authors, timestamp: r.published, tagName: tagName
                )
            }
        } catch {
            print("[Gathering] arXiv error for '\(tagName)': \(error.localizedDescription)")
            return []
        }
    }

    /// Fetch blog posts — pure network, returns value-type results.
    private nonisolated func fetchBlogs(tagName: String) async -> [FetchedItem] {
        print("[Gathering] Fetching blogs for '\(tagName)'...")
        do {
            let results = try await GoogleSearchService.shared.search(query: tagName, maxResults: 6)
            print("[Gathering] Blog search returned \(results.count) results for '\(tagName)'")
            return results.map { r in
                FetchedItem(
                    title: r.title, url: r.url, sourceType: .blog,
                    sourceName: r.source, rawText: r.snippet,
                    authors: [], timestamp: Date(), tagName: tagName
                )
            }
        } catch {
            print("[Gathering] Blog search error for '\(tagName)': \(error.localizedDescription)")
            return []
        }
    }

    /// Fetch YouTube talks — pure network, returns value-type results.
    private nonisolated func fetchYouTube(tagName: String) async -> [FetchedItem] {
        let ytKey = SettingsManager.shared.youtubeAPIKey
        guard !ytKey.isEmpty else {
            print("[Gathering] YouTube skipped for '\(tagName)' (no API key)")
            return []
        }
        print("[Gathering] Fetching YouTube for '\(tagName)'...")
        do {
            let results = try await YouTubeService.shared.search(
                query: tagName, apiKey: ytKey, maxResults: 4
            )
            print("[Gathering] YouTube returned \(results.count) results for '\(tagName)'")
            return results.map { r in
                FetchedItem(
                    title: r.title, url: r.videoURL, sourceType: .talk,
                    sourceName: r.channelName, rawText: "",
                    authors: [r.channelName], timestamp: r.publishedAt,
                    tagName: tagName, thumbnailURL: r.thumbnailURL
                )
            }
        } catch {
            print("[Gathering] YouTube error for '\(tagName)': \(error.localizedDescription)")
            return []
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

        // Attempt combined enrich (summary + score in one API call)
        do {
            if !textContent.isEmpty {
                let enriched = try await gemini.enrichContent(
                    title: item.title,
                    contentType: item.sourceType,
                    fullText: textContent,
                    authors: item.authors,
                    tagName: item.tagNames.first ?? ""
                )
                item.geminiSummary = enriched.summary.text
                item.keyTakeaways = enriched.summary.keyTakeaways
                item.isSummarized = true
                item.importanceScore = enriched.importanceScore
                item.authorMetric = enriched.authorMetric
            } else {
                print("[Gathering] No text content for \(item.title)")
            }
        } catch {
            print("[Gathering] Gemini enrich error: \(error.localizedDescription)")
        }
    }

    /// Summarise all unsummarised items in the database.
    @MainActor
    func summariseUnsummarised() async {
        guard let modelContainer else { return }

        let context = modelContainer.mainContext
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

}

