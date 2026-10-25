import StreetPiCore
import SwiftUI
import UIKit

enum Rhythm {
    static let tight: CGFloat = 6
    static let line: CGFloat = 12
    static let block: CGFloat = 22
    static let page: CGFloat = 28
}

struct StreetTheme: Equatable {
    var background: Color
    var surface: Color
    var ink: Color
    var secondary: Color
    var tertiary: Color
    var accent: Color
    var calm: Color
    var attention: Color
    var problem: Color
    var hairline: Color

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
}

enum StreetColor {
    /// Aurora ground. Shared by the design system, the house theme, and the splash tint.
    static let auroraGround: UInt32 = 0x0E0D18

    static func rgb(_ hex: UInt32) -> Color {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        return Color(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }

    static func uiColor(_ hex: UInt32) -> UIColor {
        let red = CGFloat((hex >> 16) & 0xFF) / 255
        let green = CGFloat((hex >> 8) & 0xFF) / 255
        let blue = CGFloat(hex & 0xFF) / 255
        return UIColor(red: red, green: green, blue: blue, alpha: 1)
    }
}

extension StreetTheme {
    static func house(_ scheme: ColorScheme) -> StreetTheme {
        switch scheme {
        case .light:
            let ink = StreetColor.rgb(0x1E1B2E)
            return StreetTheme(
                background: StreetColor.rgb(0xF4F3FA),
                surface: Color.white,
                ink: ink,
                secondary: StreetColor.rgb(0x4C4F69),
                tertiary: StreetColor.rgb(0x5C5F77),
                accent: StreetColor.rgb(0x5A4FCF),
                calm: StreetColor.rgb(0x2B7A1F),
                attention: StreetColor.rgb(0x8A5A00),
                problem: StreetColor.rgb(0xB4153F),
                hairline: ink.opacity(0.10)
            )
        default:
            let line = Color(.sRGB, red: 205.0 / 255, green: 214.0 / 255, blue: 244.0 / 255, opacity: 1)
            return StreetTheme(
                background: StreetColor.rgb(StreetColor.auroraGround),
                surface: StreetColor.rgb(0x17162A),
                ink: StreetColor.rgb(0xE6EAFB),
                secondary: StreetColor.rgb(0xB0B6D2),
                tertiary: StreetColor.rgb(0x8C91B0),
                accent: StreetColor.rgb(0xB4BEFE),
                calm: StreetColor.rgb(0xA6E3A1),
                attention: StreetColor.rgb(0xF9E2AF),
                problem: StreetColor.rgb(0xF38BA8),
                hairline: line.opacity(0.18)
            )
        }
    }
}
