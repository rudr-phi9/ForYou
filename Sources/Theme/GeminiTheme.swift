import SwiftUI

// MARK: - Gemini Color Theme

extension Color {
    /// Deep intelligent blue
    static let geminiBlue = Color(red: 0.25, green: 0.35, blue: 0.85)
    /// Rich purple
    static let geminiPurple = Color(red: 0.55, green: 0.25, blue: 0.85)
    /// Light variant for text on dark
    static let geminiBlueLight = Color(red: 0.45, green: 0.55, blue: 0.95)
    /// Subtle card background
    static let cardBackground = Color(nsColor: .controlBackgroundColor)
    /// Subtle separator
    static let subtleSeparator = Color(nsColor: .separatorColor)
}

extension LinearGradient {
    /// Primary blue-to-purple Gemini gradient
    static let gemini = LinearGradient(
        colors: [.geminiBlue, .geminiPurple],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// Vertical variant for backgrounds
    static let geminiVertical = LinearGradient(
        colors: [.geminiBlue.opacity(0.15), .geminiPurple.opacity(0.10)],
        startPoint: .top,
        endPoint: .bottom
    )
}

extension ShapeStyle where Self == LinearGradient {
    static var geminiGradient: LinearGradient { .gemini }
}

extension ShapeStyle where Self == Color {
    static var geminiBlue: Color { Color.geminiBlue }
    static var geminiPurple: Color { Color.geminiPurple }
    static var geminiBlueLight: Color { Color.geminiBlueLight }
    static var subtleSeparator: Color { Color.subtleSeparator }
}

// MARK: - View Modifiers

struct GeminiCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.subtleSeparator.opacity(0.3), lineWidth: 0.5)
            )
    }
}

extension View {
    func geminiCard() -> some View {
        modifier(GeminiCardStyle())
    }
}
