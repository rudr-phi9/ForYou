import SwiftUI

/// Gel-drop tag pill with liquid glass styling.
struct TagPillView: View {
    let name: String
    let isSelected: Bool
    var onTap: () -> Void = {}

    @State private var isHovered = false

    var body: some View {
        Text(name)
            .font(.caption)
            .fontWeight(isSelected ? .bold : .regular)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .foregroundStyle(isSelected ? .white : .secondary)
            .background {
                if isSelected {
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.geminiBlue.opacity(0.4),
                                    Color.geminiPurple.opacity(0.4)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .background(
                            Capsule(style: .continuous)
                                .fill(.ultraThinMaterial)
                        )
                } else {
                    Capsule(style: .continuous)
                        .fill(.ultraThinMaterial)
                }
            }
            .clipShape(Capsule(style: .continuous))
            .overlay {
                Capsule(style: .continuous)
                    .stroke(
                        isSelected
                            ? LinearGradient.glassEdge
                            : LinearGradient(
                                colors: [.white.opacity(0.2), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                              ),
                        lineWidth: isSelected ? 1 : 0.5
                    )
            }
            .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
            .scaleEffect(isHovered ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
            .contentShape(Capsule())
            .onTapGesture { onTap() }
            .onHover { hovering in
                isHovered = hovering
            }
    }
}
