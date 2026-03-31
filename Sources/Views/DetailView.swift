import SwiftUI

/// Enlarged detail view for a research item, displayed as a sheet.
/// Shows full scrollable summary, key takeaways, importance score, and actions.
struct DetailView: View {
    let item: ResearchItem
    @Environment(\.dismiss) private var dismiss
    @State private var showChat = false

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Top Bar
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Spacer()

                // Glowing orb importance
                if item.importanceScore > 0 {
                    GlowingOrb(score: item.importanceScore)
                }

                // Favorite & Save buttons
                GlassActionButton(
                    systemName: item.isFavorited ? "star.fill" : "star",
                    isActive: item.isFavorited,
                    activeColor: .yellow,
                    inactiveColor: .secondary,
                    help: item.isFavorited ? "Remove from Favorites" : "Add to Favorites"
                ) {
                    item.isFavorited.toggle()
                }

                GlassActionButton(
                    systemName: item.isBookmarked ? "bookmark.fill" : "bookmark",
                    isActive: item.isBookmarked,
                    activeColor: .geminiPurple,
                    inactiveColor: .secondary,
                    help: item.isBookmarked ? "Unsave" : "Save"
                ) {
                    item.isBookmarked.toggle()
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)

            // MARK: - Scrollable Content
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 0) {
                    // Hero image with gradient fade
                    if let imageURLString = item.heroImageURL ?? item.thumbnailURL,
                       let imageURL = URL(string: imageURLString) {
                        AsyncImage(url: imageURL) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(maxHeight: 200)
                                    .clipped()
                                    .mask(
                                        LinearGradient(
                                            colors: [.white, .white, .white.opacity(0)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                            default:
                                EmptyView()
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        // Source + Timestamp
                        HStack(spacing: 6) {
                            Image(systemName: item.sourceType.iconName)
                                .font(.caption)
                                .foregroundStyle(.neonHighlight)
                            Text(item.sourceName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(item.formattedTimestamp)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }

                        // Title
                        Text(item.title)
                            .font(.title3)
                            .fontWeight(.bold)
                            .fixedSize(horizontal: false, vertical: true)

                        // Authors
                        if !item.authors.isEmpty {
                            Text(item.authors.joined(separator: ", "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        // Tags
                        if !item.tagNames.isEmpty {
                            HStack(spacing: 4) {
                                ForEach(item.tagNames, id: \.self) { tag in
                                    Text("#\(tag.replacingOccurrences(of: " ", with: "_"))")
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.neonHighlight)
                                }
                            }
                        }

                        // Importance score
                        if item.importanceScore > 0 {
                            HStack(spacing: 8) {
                                GlowingOrb(score: item.importanceScore)
                                Text(String(format: "%.1f / 10", item.importanceScore))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                                if let metric = item.authorMetric {
                                    Text("·")
                                        .foregroundStyle(.tertiary)
                                    Text(metric)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        // MARK: - Full Summary (glass panel)
                        if item.isSummarized, let summary = item.geminiSummary {
                            VStack(alignment: .leading, spacing: 10) {
                                Label {
                                    Text(item.sourceType == .talk
                                         ? "Summary (Visual/Audio Analysis)"
                                         : "Summary (Textual Analysis)")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                } icon: {
                                    Image(systemName: "sparkles")
                                        .font(.subheadline)
                                }
                                .foregroundStyle(LinearGradient.gemini)

                                Text(summary)
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)

                                if !item.keyTakeaways.isEmpty {
                                    Text("Key Takeaways")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .padding(.top, 4)

                                    VStack(alignment: .leading, spacing: 6) {
                                        ForEach(item.keyTakeaways, id: \.self) { takeaway in
                                            HStack(alignment: .top, spacing: 6) {
                                                Text("•")
                                                    .font(.body)
                                                    .foregroundStyle(.neonHighlight)
                                                Text(takeaway)
                                                    .font(.body)
                                                    .foregroundStyle(.secondary)
                                                    .fixedSize(horizontal: false, vertical: true)
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(12)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(LinearGradient.glassEdge, lineWidth: 0.5)
                            )
                        } else {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .controlSize(.small)
                                    .frame(width: 12, height: 12)
                                Text("Awaiting analysis…")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }

                        // MARK: - Action Buttons
                        HStack(spacing: 16) {
                            Button {
                                if let url = item.sourceURL {
                                    NSWorkspace.shared.open(url)
                                }
                            } label: {
                                Label("Open Original", systemImage: "arrow.up.right.square")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.geminiBlue)

                            Button {
                                if let url = item.sourceURL {
                                    let pb = NSPasteboard.general
                                    pb.clearContents()
                                    pb.setString(url.absoluteString, forType: .string)
                                }
                            } label: {
                                Label("Copy Link", systemImage: "doc.on.doc")
                            }
                            .buttonStyle(.bordered)

                            Button {
                                showChat = true
                            } label: {
                                Label("Chat", systemImage: "bubble.left.and.bubble.right")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(20)
                }
            }
        }
        .frame(width: 500, height: 600)
        .background {
            ZStack {
                Color.clear
                FluidBackground()
                Rectangle().fill(.thinMaterial)
            }
        }
        .sheet(isPresented: $showChat) {
            ChatView(item: item)
        }
    }
}
