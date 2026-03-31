import SwiftUI

/// Material 3 Filter Chip — unselected: transparent + gray outline; selected: blue tonal fill + checkmark.
struct TagPillView: View {
    let name: String
    let isSelected: Bool
    var onTap: () -> Void = {}

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 4) {
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .transition(.scale.combined(with: .opacity))
            }
            Text(name)
                .font(GFont.captionMedium)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .foregroundStyle(isSelected ? .geminiBlue : .secondary)
        .background {
            Capsule(style: .continuous)
                .fill(isSelected ? Color.geminiBlue.opacity(0.15) : Color.clear)
        }
        .clipShape(Capsule(style: .continuous))
        .overlay {
            Capsule(style: .continuous)
                .stroke(
                    isSelected ? Color.clear : Color.primary.opacity(0.15),
                    lineWidth: 1
                )
        }
        .background {
            if isHovered && !isSelected {
                Capsule(style: .continuous)
                    .fill(Color.primary.opacity(0.04))
            }
        }
        .animation(.easeOut(duration: 0.15), value: isSelected)
        .animation(.easeOut(duration: 0.1), value: isHovered)
        .contentShape(Capsule())
        .onTapGesture { onTap() }
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
