import SwiftUI
import SwiftData

/// Content card displaying a single research item in the feed.
struct ContentCardView: View {
    let item: ResearchItem
    var onTap: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // MARK: - Header: Source + Timestamp + Glowing Orb
            HStack(spacing: 6) {
                Image(systemName: item.sourceType.iconName)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(item.sourceName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()

                // Glowing orb importance indicator
                if item.importanceScore > 0 {
                    GlowingOrb(score: item.importanceScore)
                }

                Text(item.formattedTimestamp)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            // MARK: - Multimodal Preview Image
            if let imageURLString = item.heroImageURL ?? item.thumbnailURL,
               let imageURL = URL(string: imageURLString) {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxHeight: 140)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    case .failure:
                        previewPlaceholder
                    default:
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 16, height: 16)
                            .frame(maxWidth: .infinity, maxHeight: 80)
                    }
                }
            } else if item.sourceType == .paper {
                // Paper icon placeholder
                HStack {
                    Spacer()
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(.linearGradient(
                            colors: [.geminiBlue.opacity(0.6), .geminiPurple.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                    Spacer()
                }
                .frame(height: 60)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }

            // MARK: - Title
            Text(item.title)
                .font(.system(.subheadline, weight: .semibold))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            // MARK: - Tags
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

            // MARK: - AI Summary Block
            if item.isSummarized, let summary = item.geminiSummary {
                VStack(alignment: .leading, spacing: 6) {
                    Label {
                        Text(item.sourceType == .talk
                             ? "Summary (Visual/Audio Analysis)"
                             : "Summary (Textual Analysis)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                    } icon: {
                        Image(systemName: "sparkles")
                            .font(.caption2)
                    }
                    .foregroundStyle(LinearGradient.gemini)

                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(6)

                    if !item.keyTakeaways.isEmpty {
                        VStack(alignment: .leading, spacing: 3) {
                            ForEach(item.keyTakeaways, id: \.self) { takeaway in
                                HStack(alignment: .top, spacing: 4) {
                                    Text("•")
                                        .font(.caption)
                                        .foregroundStyle(.neonHighlight)
                                    Text(takeaway)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                        }
                    }
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(LinearGradient.glassEdge, lineWidth: 0.5)
                )
            } else if !item.isDiscarded {
                HStack(spacing: 4) {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 12, height: 12)
                    Text("Awaiting analysis…")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            // MARK: - Footer Actions
            HStack(spacing: 8) {
                GlassActionButton(
                    systemName: "arrow.up.right.square",
                    isActive: false,
                    activeColor: .neonHighlight,
                    inactiveColor: .neonHighlight,
                    help: "Open Original"
                ) {
                    if let url = item.sourceURL {
                        NSWorkspace.shared.open(url)
                    }
                }

                GlassActionButton(
                    systemName: item.isFavorited ? "star.fill" : "star",
                    isActive: item.isFavorited,
                    activeColor: .yellow,
                    inactiveColor: .secondary,
                    help: item.isFavorited ? "Remove from Favorites" : "Favorite"
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

                GlassActionButton(
                    systemName: "square.and.arrow.up",
                    isActive: false,
                    activeColor: .secondary,
                    inactiveColor: .secondary,
                    help: "Copy Link"
                ) {
                    if let url = item.sourceURL {
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(url.absoluteString, forType: .string)
                    }
                }

                Spacer()
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .geminiCard()
    }

    private var previewPlaceholder: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(.quaternary)
            .frame(height: 60)
            .overlay {
                Image(systemName: "photo")
                    .foregroundStyle(.tertiary)
            }
    }
}
