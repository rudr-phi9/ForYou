import SwiftUI

/// Enlarged detail view for a research item, displayed as a sheet.
/// Shows full scrollable summary, key takeaways, importance score, and actions.
struct DetailView: View {
    let item: ResearchItem
    @Environment(\.dismiss) private var dismiss

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

                // Importance badge
                if item.importanceScore > 0 {
                    importanceBadge
                }

                // Favorite & Save buttons
                Button { item.isFavorited.toggle() } label: {
                    Image(systemName: item.isFavorited ? "star.fill" : "star")
                        .font(.title3)
                        .foregroundStyle(item.isFavorited ? .yellow : .secondary)
                }
                .buttonStyle(.plain)
                .help(item.isFavorited ? "Remove from Favorites" : "Add to Favorites")

                Button { item.isBookmarked.toggle() } label: {
                    Image(systemName: item.isBookmarked ? "bookmark.fill" : "bookmark")
                        .font(.title3)
                        .foregroundStyle(item.isBookmarked ? .geminiPurple : .secondary)
                }
                .buttonStyle(.plain)
                .help(item.isBookmarked ? "Unsave" : "Save")
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)

            Divider()

            // MARK: - Scrollable Content
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 16) {
                    // Source + Timestamp
                    HStack(spacing: 6) {
                        Image(systemName: item.sourceType.iconName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(item.sourceName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(item.formattedTimestamp)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    // Hero image
                    if let imageURLString = item.heroImageURL ?? item.thumbnailURL,
                       let imageURL = URL(string: imageURLString) {
                        AsyncImage(url: imageURL) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            default:
                                EmptyView()
                            }
                        }
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
                                    .foregroundStyle(.geminiBlue)
                            }
                        }
                    }

                    // Importance score
                    if item.importanceScore > 0 {
                        HStack(spacing: 8) {
                            importanceBadge
                            if let metric = item.authorMetric {
                                Text(metric)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Divider()

                    // MARK: - Full Summary (scrollable)
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
                                .foregroundStyle(.primary)
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
                                                .foregroundStyle(.geminiPurple)
                                            Text(takeaway)
                                                .font(.body)
                                                .foregroundStyle(.primary)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(LinearGradient.geminiVertical)
                        )
                    } else {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small)
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
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 500, height: 600)
        .background(.ultraThickMaterial)
    }

    // MARK: - Importance Badge

    private var importanceBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "chart.bar.fill")
                .font(.caption2)
            Text(String(format: "%.1f", item.importanceScore))
                .font(.caption)
                .fontWeight(.bold)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .foregroundStyle(.white)
        .background(importanceColor)
        .clipShape(Capsule())
    }

    private var importanceColor: Color {
        switch item.importanceScore {
        case 8...10: return .green
        case 6..<8: return .geminiBlue
        case 4..<6: return .orange
        default: return .gray
        }
    }
}
