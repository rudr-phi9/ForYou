import SwiftUI

// MARK: - Google AI Color Palette ("Gemini Aura")

extension Color {
    /// Google AI Blue — primary interactive
    static let geminiBlue = Color(red: 0.102, green: 0.451, blue: 0.910)   // #1A73E8
    /// Gemini Deep Purple — depth elements, saved states
    static let geminiPurple = Color(red: 0.408, green: 0.114, blue: 0.659) // #681DA8
    /// Sparkle Magenta — warning, high-priority
    static let sparkleMagenta = Color(red: 0.851, green: 0.188, blue: 0.145) // #D93025
    /// Google Green — high importance
    static let googleGreen = Color(red: 0.059, green: 0.616, blue: 0.345)  // #0F9D58
    /// Google Yellow — medium importance
    static let googleYellow = Color(red: 0.957, green: 0.706, blue: 0.0)   // #F4B400
    /// Google Blue semantic — medium-high importance
    static let googleBlue = Color(red: 0.263, green: 0.522, blue: 0.957)   // #4285F4
    /// Neon highlight — retained for compatibility, now mapped to Google AI Blue
    static let neonHighlight = Color(red: 0.102, green: 0.451, blue: 0.910)
    /// Light variant
    static let geminiBlueLight = Color(red: 0.45, green: 0.55, blue: 0.95)
    /// Surface Tonal Light
    static let surfaceTonalLight = Color(red: 0.973, green: 0.976, blue: 0.980) // #F8F9FA
    /// Surface Tonal Dark
    static let surfaceTonalDark = Color(red: 0.125, green: 0.129, blue: 0.141)  // #202124
    /// Subtle separator
    static let subtleSeparator = Color(nsColor: .separatorColor)
    /// Surface tonal — adapts to color scheme
    static let surfaceTonal = Color(nsColor: .controlBackgroundColor)
}

// MARK: - Google Typography

/// Google-inspired typography system using system fonts with geometric/rounded design
struct GFont {
    /// Brand & App Title — Google Sans Display equivalent (18pt medium, rounded)
    static let displayTitle = Font.system(size: 18, weight: .medium, design: .rounded)
    /// Headers & Titles — Google Sans equivalent (medium/bold)
    static func title(_ weight: Font.Weight = .medium) -> Font {
        .system(size: 15, weight: weight, design: .rounded)
    }
    /// Card titles
    static let cardTitle = Font.system(size: 13, weight: .semibold, design: .rounded)
    /// Body & Summaries — Google Sans Text equivalent (13pt, wider tracking)
    static let body = Font.system(size: 13, weight: .regular, design: .default)
    /// Body medium
    static let bodyMedium = Font.system(size: 13, weight: .medium, design: .default)
    /// Caption
    static let caption = Font.system(size: 11, weight: .regular, design: .default)
    /// Caption medium
    static let captionMedium = Font.system(size: 11, weight: .medium, design: .default)
    /// Small caption
    static let caption2 = Font.system(size: 10, weight: .regular, design: .default)
    /// Code & Technical Data — Roboto Mono equivalent (12pt monospaced)
    static let mono = Font.system(size: 12, weight: .regular, design: .monospaced)
    /// Mono small for importance scores
    static let monoSmall = Font.system(size: 11, weight: .bold, design: .monospaced)
    /// Chat body
    static let chat = Font.system(size: 13, weight: .regular, design: .default)
}

extension LinearGradient {
    /// Aura Gradient: Blue → Purple → Magenta (Google AI signature)
    static let gemini = LinearGradient(
        colors: [.geminiBlue, .geminiPurple, .sparkleMagenta.opacity(0.6)],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// Aura Gradient — vertical for backgrounds
    static let geminiVertical = LinearGradient(
        colors: [.geminiBlue.opacity(0.12), .geminiPurple.opacity(0.08)],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Soft Edge — Google's subtle tonal border (replaces hard specular edge)
    static let glassEdge = LinearGradient(
        colors: [.primary.opacity(0.08), .primary.opacity(0.04)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Aura border — visible on hover/AI activation
    static let auraBorder = LinearGradient(
        colors: [.geminiBlue.opacity(0.4), .geminiPurple.opacity(0.3), .sparkleMagenta.opacity(0.2)],
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

// MARK: - Material Glass Card (Google Material 3 Style)

struct LiquidGlassCardStyle: ViewModifier {
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .padding(14)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        isHovered ? LinearGradient.auraBorder : LinearGradient.glassEdge,
                        lineWidth: 1
                    )
            )
            // Elevation: resting = Level 1, hover = Level 3
            .shadow(color: .black.opacity(isHovered ? 0.12 : 0.08), radius: isHovered ? 12 : 6, x: 0, y: isHovered ? 6 : 2)
            .animation(.easeOut(duration: 0.15), value: isHovered)
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

// MARK: - Signal Ring (Importance Indicator — Material 3)

struct SignalRing: View {
    let score: Double

    private var ringColor: Color {
        switch score {
        case 8...10: return .googleGreen
        case 6..<8: return .googleBlue
        case 4..<6: return .googleYellow
        default: return .gray
        }
    }

    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(Color.primary.opacity(0.08), lineWidth: 2.5)
                .frame(width: 32, height: 32)

            // Progress arc
            Circle()
                .trim(from: 0, to: min(score / 10.0, 1.0))
                .stroke(ringColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .frame(width: 32, height: 32)
                .rotationEffect(.degrees(-90))

            // Score text
            Text(String(format: "%.1f", score))
                .font(GFont.monoSmall)
                .foregroundStyle(.primary.opacity(0.85))
        }
    }
}

// MARK: - Shimmer Skeleton Loader

struct ShimmerView: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(Color.primary.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.clear, .primary.opacity(0.06), .clear],
                            startPoint: .init(x: phase - 0.5, y: 0.5),
                            endPoint: .init(x: phase + 0.5, y: 0.5)
                        )
                    )
            )
            .onAppear {
                withAnimation(
                    .linear(duration: 1.5)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 2.0
                }
            }
    }
}

/// Multi-line shimmer placeholder for loading summary content
struct ShimmerSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ShimmerView().frame(height: 10)
            ShimmerView().frame(width: 260, height: 10)
            ShimmerView().frame(width: 200, height: 10)
            HStack(spacing: 6) {
                ShimmerView().frame(width: 16, height: 10)
                ShimmerView().frame(width: 180, height: 10)
            }
            HStack(spacing: 6) {
                ShimmerView().frame(width: 16, height: 10)
                ShimmerView().frame(width: 150, height: 10)
            }
        }
        .padding(10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(LinearGradient.glassEdge, lineWidth: 0.5)
        )
    }
}

// MARK: - Fluid Background (Aura Blobs)

struct FluidBackground: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            // Blob 1 — Google AI Blue
            Circle()
                .fill(Color.geminiBlue.opacity(0.45))
                .frame(width: 200, height: 200)
                .blur(radius: 60)
                .offset(x: animate ? 50 : -50, y: animate ? -30 : 40)

            // Blob 2 — Gemini Deep Purple
            Circle()
                .fill(Color.geminiPurple.opacity(0.35))
                .frame(width: 180, height: 180)
                .blur(radius: 55)
                .offset(x: animate ? -60 : 40, y: animate ? 50 : -40)

            // Blob 3 — Sparkle Magenta (subtle)
            Circle()
                .fill(Color.sparkleMagenta.opacity(0.08))
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

// MARK: - Google-Style Action Button (State Layer)

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
                .foregroundStyle(isActive ? activeColor : (isHovered ? .geminiBlue : inactiveColor))
                .frame(width: 32, height: 32)
                .background {
                    if isHovered {
                        Circle()
                            .fill(Color.primary.opacity(0.06))
                    }
                }
                .clipShape(Circle())
                .animation(.easeOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Gemini Sparkle Icon (Aura Gradient)

struct GeminiSparkle: View {
    var size: CGFloat = 14

    var body: some View {
        Image(systemName: "sparkles")
            .font(.system(size: size))
            .foregroundStyle(LinearGradient.gemini)
    }
}
