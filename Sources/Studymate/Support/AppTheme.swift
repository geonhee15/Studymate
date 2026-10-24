import AppKit
import SwiftUI
import Observation

/// Light / dark / follow-system for this app's windows only.
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "시스템"
        case .light: return "라이트"
        case .dark: return "다크"
        }
    }

    var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }
}

/// Selectable skins. Colors drive the SwiftUI views (via `Theme`) and the window backdrop tint.
enum AppTheme: String, CaseIterable, Identifiable {
    case studymate, jarvis, midnight, sage

    var id: String { rawValue }

    var title: String {
        switch self {
        case .studymate: return "기본"
        case .jarvis: return "JARVIS"
        case .midnight: return "미드나이트"
        case .sage: return "세이지"
        }
    }

    var subtitle: String {
        switch self {
        case .studymate: return "macOS 시스템 강조색 · 흰 유리"
        case .jarvis: return "네이비 + 시안"
        case .midnight: return "어두운 회색 + 인디고"
        case .sage: return "밝은 유리 + 세이지 그린"
        }
    }

    var accent: Color {
        switch self {
        case .studymate: return .accentColor
        case .jarvis: return Color(red: 0.235, green: 0.863, blue: 1.0)
        case .midnight: return Color(red: 0.43, green: 0.48, blue: 1.0)
        case .sage: return Color(red: 0.18, green: 0.64, blue: 0.42)
        }
    }

    /// Hex string for the web views (KaTeX pages pick up the same accent).
    var accentHex: String {
        switch self {
        case .studymate:
            let c = NSColor.controlAccentColor.usingColorSpace(.sRGB) ?? NSColor.systemBlue
            return String(format: "#%02X%02X%02X", Int(c.redComponent * 255), Int(c.greenComponent * 255), Int(c.blueComponent * 255))
        case .jarvis: return "#3CDCFF"
        case .midnight: return "#6E7AFF"
        case .sage: return "#2EA36B"
        }
    }

    /// Dark skins force the dark appearance regardless of the appearance setting.
    var forcedAppearance: NSAppearance? {
        switch self {
        case .jarvis, .midnight: return NSAppearance(named: .darkAqua)
        case .studymate, .sage: return nil
        }
    }

    /// Translucent color laid over the blur behind the window content.
    var tint: NSColor? {
        switch self {
        case .studymate: return nil
        case .jarvis: return NSColor(srgbRed: 0.02, green: 0.07, blue: 0.16, alpha: 0.55)
        case .midnight: return NSColor(srgbRed: 0.05, green: 0.05, blue: 0.08, alpha: 0.55)
        case .sage: return NSColor(srgbRed: 0.55, green: 0.75, blue: 0.60, alpha: 0.10)
        }
    }
}

@MainActor
@Observable
final class ThemeManager {
    static let shared = ThemeManager()
    private static let themeKey = "appTheme"
    private static let appearanceKey = "appearanceMode"

    private(set) var current: AppTheme
    private(set) var appearance: AppearanceMode
    @ObservationIgnored var onChange: (() -> Void)?

    private init() {
        let env = ProcessInfo.processInfo.environment
        // STUDYMATE_DEBUG_THEME / STUDYMATE_DEBUG_APPEARANCE override the saved choice for one run (snapshots).
        current = AppTheme(rawValue: env["STUDYMATE_DEBUG_THEME"] ?? "") ?? AppTheme(rawValue: UserDefaults.standard.string(forKey: Self.themeKey) ?? "") ?? .studymate
        appearance = AppearanceMode(rawValue: env["STUDYMATE_DEBUG_APPEARANCE"] ?? "") ?? AppearanceMode(rawValue: UserDefaults.standard.string(forKey: Self.appearanceKey) ?? "") ?? .system
    }

    func set(_ theme: AppTheme) {
        current = theme
        UserDefaults.standard.set(theme.rawValue, forKey: Self.themeKey)
        onChange?()
    }

    func setAppearance(_ mode: AppearanceMode) {
        appearance = mode
        UserDefaults.standard.set(mode.rawValue, forKey: Self.appearanceKey)
        onChange?()
    }

    /// What the window should actually show: dark skins win over the appearance setting.
    var effectiveAppearance: NSAppearance? {
        current.forcedAppearance ?? appearance.nsAppearance
    }
}
