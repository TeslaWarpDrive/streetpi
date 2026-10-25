import StreetPiCore
import SwiftUI

/// Aurora, dark only.
/// Text and status colors are the Catppuccin Mocha pair from COLORS.md (MIT).
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

    /// Blob strength. A zero amount stays clear.
    func wash(_ color: Color, amount: Double) -> Color {
        guard amount > 0 else { return color.opacity(0) }
        return color.opacity(amount)
    }

    static func resolve(contrast: ColorSchemeContrast) -> AfterglowPalette {
        night(contrast: contrast)
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
            auraPink: StreetColor.rgb(0xF49BDD)
        )
    }
}
