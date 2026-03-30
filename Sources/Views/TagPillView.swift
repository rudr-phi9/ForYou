import SwiftUI

/// Capsule-shaped tag pill with Gemini gradient highlighting.
struct TagPillView: View {
    let name: String
    let isSelected: Bool
    var onTap: () -> Void = {}

    var body: some View {
        Text(name)
            .font(.caption)
            .fontWeight(isSelected ? .semibold : .regular)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .foregroundStyle(isSelected ? .white : .primary)
            .background {
                if isSelected {
                    Capsule(style: .continuous)
                        .fill(LinearGradient.gemini)
                } else {
                    Capsule(style: .continuous)
                        .fill(.quaternary)
                }
            }
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.clear : Color.subtleSeparator.opacity(0.3),
                        lineWidth: 0.5
                    )
            }
            .contentShape(Capsule())
            .onTapGesture { onTap() }
    }
}
