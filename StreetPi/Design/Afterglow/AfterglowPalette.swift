import StreetPiCore
import SwiftUI

/// Aurora, dark first. Light is the same hues on paper.
/// Text and status colors are the Catppuccin Mocha / Latte pairs from COLORS.md (MIT).
/// The glow stops are rebuilt in SwiftUI. No shader source is included.
struct AfterglowPalette: Equatable {
    var ground: Color
    var panel: Color
    var panelRaised: Color
    var hairline: Color
    var hairlineInteractive: Color
    var ink: Color
    var secondary: Color
    var tertiary: Color
    var accent: Color
    var accentGlow: Color
    var calm: Color
    var attention: Color
    var problem: Color
    var auraTeal: Color
    var auraBlue: Color
    var auraViolet: Color
    var auraPink: Color
    /// 1 in the dark. Light washes the same hues to about 35% on paper.
    var auraOpacity: Double
    /// Dark rings carry the glow. Light rings stay a solid accent.
    var ringsUseGradient: Bool

    func tone(_ tone: PlainEnglishStatus.Tone) -> Color {
        switch tone {
        case .calm:
            calm
        case .attention:
            attention
        case .problem:
            problem
        }
    }

    var auraStops: [Color] {
        [auraTeal, auraBlue, auraViolet, auraPink]
    }

    /// Blob strength. A zero amount stays clear. Light mode caps the hue at the paper wash.
    func wash(_ color: Color, amount: Double) -> Color {
        guard amount > 0 else { return color.opacity(0) }
        if auraOpacity < 1 {
            return color.opacity(auraOpacity)
        }
        return color.opacity(amount)
    }

    static func resolve(_ scheme: ColorScheme, contrast: ColorSchemeContrast) -> AfterglowPalette {
        switch scheme {
        case .light:
            daylight(contrast: contrast)
        default:
            night(contrast: contrast)
        }
    }

    static func night(contrast: ColorSchemeContrast) -> AfterglowPalette {
        let strong = contrast == .increased
        let line = Color(.sRGB, red: 205.0 / 255, green: 214.0 / 255, blue: 244.0 / 255, opacity: 1)
        return AfterglowPalette(
            ground: StreetColor.rgb(StreetColor.auroraGround),
            panel: StreetColor.rgb(0x17162A),
            panelRaised: StreetColor.rgb(0x201F36),
            hairline: line.opacity(strong ? 0.28 : 0.12),
            hairlineInteractive: line.opacity(strong ? 0.36 : 0.22),
            ink: StreetColor.rgb(0xE6EAFB),
            secondary: StreetColor.rgb(0xB0B6D2),
            tertiary: StreetColor.rgb(0x8C91B0),
            accent: StreetColor.rgb(0xB4BEFE),
            accentGlow: StreetColor.rgb(0x8B7CF6),
            calm: StreetColor.rgb(0xA6E3A1),
            attention: StreetColor.rgb(0xF9E2AF),
            problem: StreetColor.rgb(0xF38BA8),
            auraTeal: StreetColor.rgb(0x4FE3CF),
            auraBlue: StreetColor.rgb(0x8E9BFF),
            auraViolet: StreetColor.rgb(0xB78CFF),
            auraPink: StreetColor.rgb(0xF49BDD),
            auraOpacity: 1,
            ringsUseGradient: true
        )
    }

    static func daylight(contrast: ColorSchemeContrast) -> AfterglowPalette {
        let strong = contrast == .increased
        let ink = StreetColor.rgb(0x1E1B2E)
        return AfterglowPalette(
            ground: StreetColor.rgb(0xF4F3FA),
            panel: Color.white,
            panelRaised: Color.white,
            hairline: ink.opacity(strong ? 0.24 : 0.10),
            hairlineInteractive: ink.opacity(strong ? 0.28 : 0.16),
            ink: ink,
            secondary: StreetColor.rgb(0x4C4F69),
            tertiary: StreetColor.rgb(0x5C5F77),
            accent: StreetColor.rgb(0x5A4FCF),
            accentGlow: StreetColor.rgb(0x5A4FCF),
            calm: StreetColor.rgb(0x2B7A1F),
            attention: StreetColor.rgb(0x8A5A00),
            problem: StreetColor.rgb(0xB4153F),
            auraTeal: StreetColor.rgb(0x4FE3CF),
            auraBlue: StreetColor.rgb(0x8E9BFF),
            auraViolet: StreetColor.rgb(0xB78CFF),
            auraPink: StreetColor.rgb(0xF49BDD),
            auraOpacity: 0.35,
            ringsUseGradient: false
        )
    }
}
