import SwiftUI
import SwiftData

/// Content card displaying a single research item in the feed.
struct ContentCardView: View {
    let item: ResearchItem
    var onTap: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // MARK: - Header: Source + Timestamp + Importance
            HStack(spacing: 6) {
                Image(systemName: item.sourceType.iconName)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(item.sourceName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()

                // Importance badge
                if item.importanceScore > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 8))
                        Text(String(format: "%.1f", item.importanceScore))
                            .font(.caption2)
                            .fontWeight(.bold)
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .foregroundStyle(.white)
                    .background(importanceColor)
                    .clipShape(Capsule())
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
                            .foregroundStyle(.geminiBlue)
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
                                        .foregroundStyle(.geminiPurple)
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
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(LinearGradient.geminiVertical)
                )
            } else if !item.isDiscarded {
                HStack(spacing: 4) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Awaiting analysis…")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            // MARK: - Footer Actions
            HStack(spacing: 12) {
                Button {
                    if let url = item.sourceURL {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.geminiBlue)
                .help("Open Original")

                Button {
                    item.isFavorited.toggle()
                } label: {
                    Image(systemName: item.isFavorited ? "star.fill" : "star")
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .foregroundStyle(item.isFavorited ? .yellow : .secondary)
                .help(item.isFavorited ? "Remove from Favorites" : "Favorite")

                Button {
                    item.isBookmarked.toggle()
                } label: {
                    Image(systemName: item.isBookmarked ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .foregroundStyle(item.isBookmarked ? .geminiPurple : .secondary)
                .help(item.isBookmarked ? "Unsave" : "Save")

                Button {
                    if let url = item.sourceURL {
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(url.absoluteString, forType: .string)
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Copy Link")

                Spacer()
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .geminiCard()
    }

    // MARK: - Importance Color

    private var importanceColor: Color {
        switch item.importanceScore {
        case 8...10: return .green
        case 6..<8: return .geminiBlue
        case 4..<6: return .orange
        default: return .gray
        }
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
