import SwiftUI

/// Shared look: card fills, accent, radii. Mirrors the ATFM conventions so both apps feel alike.
@MainActor
enum Theme {
    nonisolated static let cardRadius: CGFloat = 12

    /// Accent color of the selected skin (see AppTheme / ThemeManager).
    static var accent: Color { ThemeManager.shared.current.accent }

    static func cardFill(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.07) : Color.white.opacity(0.62)
    }

    static func cardStroke(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.06)
    }

    static func hoverFill(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.045)
    }

    static func chipFill(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.06)
    }

    static func sidebarSelection(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08)
    }

    /// Mastery colors, Khan-style ramp from light to full accent, crown level in green.
    static func mastery(_ level: MasteryLevel) -> Color {
        switch level {
        case .none: return Color.secondary.opacity(0.35)
        case .attempted: return Color.orange
        case .familiar: return accent.opacity(0.55)
        case .proficient: return accent
        case .mastered: return Color(red: 0.16, green: 0.62, blue: 0.40)
        }
    }

    static let correct = Color(red: 0.16, green: 0.62, blue: 0.40)
    static let wrong = Color(red: 0.86, green: 0.26, blue: 0.24)
}

struct CardBackground: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    var radius: CGFloat

    func body(content: Content) -> some View {
        content
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Theme.cardFill(scheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Theme.cardStroke(scheme), lineWidth: 1)
                    .allowsHitTesting(false)
            )
    }
}

extension View {
    func card(radius: CGFloat = Theme.cardRadius) -> some View {
        modifier(CardBackground(radius: radius))
    }
}
