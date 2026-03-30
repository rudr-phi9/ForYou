import SwiftUI

// MARK: - Liquid Glass Color Palette

extension Color {
    /// Liquid Blue — brighter, saturated
    static let geminiBlue = Color(red: 0.1, green: 0.3, blue: 0.95)
    /// Liquid Purple — vivid
    static let geminiPurple = Color(red: 0.6, green: 0.1, blue: 0.95)
    /// Neon cyan highlight for links/accents
    static let neonHighlight = Color(red: 0.0, green: 0.9, blue: 0.8)
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

    /// Glass edge specular highlight
    static let glassEdge = LinearGradient(
        colors: [.white.opacity(0.4), .clear, .white.opacity(0.1)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

extension ShapeStyle where Self == LinearGradient {
    static var geminiGradient: LinearGradient { .gemini }
}

extension ShapeStyle where Self == Color {
    static var geminiBlue: Color { Color.geminiBlue }
    static var geminiPurple: Color { Color.geminiPurple }
    static var geminiBlueLight: Color { Color.geminiBlueLight }
    static var neonHighlight: Color { Color.neonHighlight }
    static var subtleSeparator: Color { Color.subtleSeparator }
}

// MARK: - Liquid Glass Card Modifier

struct LiquidGlassCardStyle: ViewModifier {
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .padding(12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        LinearGradient.glassEdge,
                        lineWidth: 1
                    )
                    .opacity(isHovered ? 1.0 : 0.6)
            )
            .shadow(color: .black.opacity(isHovered ? 0.2 : 0.15), radius: 10, x: 0, y: 5)
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

extension View {
    func geminiCard() -> some View {
        modifier(LiquidGlassCardStyle())
    }
}

// MARK: - Glowing Orb (Importance Indicator)

struct GlowingOrb: View {
    let score: Double

    private var orbColor: Color {
        switch score {
        case 8...10: return .green
        case 6..<8: return .geminiBlue
        case 4..<6: return .orange
        default: return .gray
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [orbColor, orbColor.opacity(0.0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 20
                    )
                )
                .frame(width: 40, height: 40)
                .blur(radius: 8)

            Text(String(format: "%.1f", score))
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Fluid Background (Animated Blobs)

struct FluidBackground: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            // Blob 1
            Circle()
                .fill(Color.geminiBlue.opacity(0.6))
                .frame(width: 200, height: 200)
                .blur(radius: 60)
                .offset(x: animate ? 50 : -50, y: animate ? -30 : 40)

            // Blob 2
            Circle()
                .fill(Color.geminiPurple.opacity(0.5))
                .frame(width: 180, height: 180)
                .blur(radius: 55)
                .offset(x: animate ? -60 : 40, y: animate ? 50 : -40)

            // Blob 3
            Circle()
                .fill(Color.neonHighlight.opacity(0.15))
                .frame(width: 140, height: 140)
                .blur(radius: 50)
                .offset(x: animate ? 30 : -30, y: animate ? -50 : 30)
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 8)
                .repeatForever(autoreverses: true)
            ) {
                animate = true
            }
        }
    }
}

// MARK: - Glass Action Button

struct GlassActionButton: View {
    let systemName: String
    let isActive: Bool
    let activeColor: Color
    let inactiveColor: Color
    let help: String
    var action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14))
                .foregroundStyle(isActive ? activeColor : (isHovered ? .neonHighlight : inactiveColor))
                .padding(6)
                .background {
                    if isHovered {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Circle()
                                    .stroke(LinearGradient.glassEdge, lineWidth: 0.5)
                            )
                    }
                }
                .animation(.easeInOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
