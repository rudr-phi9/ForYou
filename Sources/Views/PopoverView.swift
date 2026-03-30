import SwiftUI
import SwiftData

/// The primary popover panel: "For You" research feed.
struct PopoverView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @Query(
        filter: #Predicate<ResearchItem> { !$0.isDiscarded },
        sort: \ResearchItem.timestamp,
        order: .reverse
    )
    private var allItems: [ResearchItem]

    @Query(
        filter: #Predicate<Tag> { $0.isActive },
        sort: \Tag.name
    )
    private var activeTags: [Tag]

    @State private var showSettings = false

    // Filtered items
    private var displayedItems: [ResearchItem] {
        var items = allItems

        // Apply feed filter (favorites / saved)
        switch appState.feedFilter {
        case .favorites:
            items = items.filter { $0.isFavorited }
        case .saved:
            items = items.filter { $0.isBookmarked }
        case .all:
            break
        }

        // Apply tag filter
        if let filter = appState.selectedTagFilter {
            items = items.filter { $0.tagNames.contains(filter) }
        }

        // Apply importance score filter
        if appState.minimumImportance > 0 {
            items = items.filter { $0.importanceScore >= appState.minimumImportance }
        }

        return items
    }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header
            header
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

            Divider()

            // MARK: - Tag Filter Bar
            if !activeTags.isEmpty {
                tagBar
                    .padding(.vertical, 6)

                Divider()
            }

            // MARK: - Feed
            if allItems.isEmpty && appState.feedFilter == .all {
                emptyState
            } else if displayedItems.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    if appState.minimumImportance > 0 {
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(.tertiary)
                        Text("No items with importance \(Int(appState.minimumImportance))+ yet")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("Show all") {
                            appState.minimumImportance = 0
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.geminiBlue)
                        .font(.caption)
                    } else {
                        Image(systemName: appState.feedFilter == .favorites ? "star" : "bookmark")
                            .font(.system(size: 30))
                            .foregroundStyle(.tertiary)
                        Text("No \(appState.feedFilter.rawValue.lowercased()) items yet")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVStack(spacing: 8) {
                            ForEach(displayedItems) { item in
                                ContentCardView(item: item) {
                                    appState.selectedItem = item
                                }
                                .id(item.id)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                    .onChange(of: appState.scrollToItemId) { _, newId in
                        if let id = newId {
                            withAnimation {
                                proxy.scrollTo(id, anchor: .top)
                            }
                            appState.scrollToItemId = nil
                        }
                    }
                }
            }
        }
        .frame(width: 400, height: 580)
        .background {
            ZStack {
                Color.clear
                FluidBackground()
                Rectangle().fill(.thinMaterial)
            }
        }
        .sheet(isPresented: $showSettings) {
            TagsSettingsView()
                .frame(width: 420, height: 480)
        }
        .sheet(item: Binding(
            get: { appState.selectedItem },
            set: { appState.selectedItem = $0 }
        )) { item in
            DetailView(item: item)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Text("For You")
                .font(.system(.title3, weight: .bold))

            Spacer()

            // Favorites filter
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    appState.feedFilter = appState.feedFilter == .favorites ? .all : .favorites
                }
            } label: {
                Image(systemName: appState.feedFilter == .favorites ? "star.fill" : "star")
                    .font(.system(size: 14, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(appState.feedFilter == .favorites ? .yellow : .secondary)
            .help("Favorites")

            // Saved filter
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    appState.feedFilter = appState.feedFilter == .saved ? .all : .saved
                }
            } label: {
                Image(systemName: appState.feedFilter == .saved ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 14, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(appState.feedFilter == .saved ? .geminiPurple : .secondary)
            .help("Saved")

            // Importance score filter
            Menu {
                Button("All scores") {
                    appState.minimumImportance = 0
                }
                Divider()
                ForEach([4.0, 6.0, 7.0, 8.0, 9.0], id: \.self) { score in
                    Button("\(Int(score))+ importance") {
                        appState.minimumImportance = score
                    }
                }
            } label: {
                HStack(spacing: 2) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 13, weight: .medium))
                    if appState.minimumImportance > 0 {
                        Text("\(Int(appState.minimumImportance))+")
                            .font(.system(size: 10, weight: .bold))
                    }
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .foregroundStyle(appState.minimumImportance > 0 ? .geminiBlue : .secondary)
            .help("Filter by importance score")

            // Sync button
            Button {
                Task {
                    await GatheringService.shared.syncNow(appState: appState)
                }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14, weight: .medium))
                    .rotationEffect(.degrees(appState.isSyncing ? 360 : 0))
                    .animation(
                        appState.isSyncing
                            ? .linear(duration: 1).repeatForever(autoreverses: false)
                            : .default,
                        value: appState.isSyncing
                    )
            }
            .buttonStyle(.plain)
            .foregroundStyle(.geminiBlue)
            .disabled(appState.isSyncing)
            .help("Sync Now")

            // Settings gear
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 14, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Settings")
        }
    }

    // MARK: - Tag Bar

    @ViewBuilder
    private var tagBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                // "All" pill
                TagPillView(
                    name: "All",
                    isSelected: appState.selectedTagFilter == nil
                ) {
                    appState.selectedTagFilter = nil
                }

                ForEach(activeTags) { tag in
                    TagPillView(
                        name: tag.hashtag,
                        isSelected: appState.selectedTagFilter == tag.name
                    ) {
                        appState.selectedTagFilter = (appState.selectedTagFilter == tag.name) ? nil : tag.name
                    }
                }
            }
            .padding(.horizontal, 12)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundStyle(LinearGradient.gemini)

            Text("No Research Yet")
                .font(.headline)

            if activeTags.isEmpty {
                Text("Add some research topics in Settings to get started.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("Open Settings") {
                    showSettings = true
                }
                .buttonStyle(.borderedProminent)
                .tint(.geminiBlue)
            } else if !SettingsManager.shared.hasAPIKey {
                Text("Add your AI API key in Settings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("Open Settings") {
                    showSettings = true
                }
                .buttonStyle(.borderedProminent)
                .tint(.geminiBlue)
            } else {
                Text("Tap Sync to fetch the latest research.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    Task {
                        await GatheringService.shared.syncNow(appState: appState)
                    }
                } label: {
                    Label("Sync Now", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
                .tint(.geminiBlue)
            }

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
}
