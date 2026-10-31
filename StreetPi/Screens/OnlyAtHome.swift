import StreetPiCore
import SwiftUI

/// A calm stand-in for anything that stays on the home network.
struct OnlyAtHomeNote: View {
    var detail: String
    var theme: StreetTheme

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Rhythm.line) {
            Image(systemName: "house")
                .font(.title3)
                .foregroundStyle(theme.accent)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Rhythm.tight) {
                Text(AwayCopy.onlyAtHomeTitle)
                    .font(.headline)
                    .foregroundStyle(theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .controlPlate(theme: theme)
        .accessibilityElement(children: .combine)
    }
}

/// A whole page that waits for the home Wi-Fi.
struct OnlyAtHomePage: View {
    var title: String
    var line: String
    var theme: StreetTheme
    var wide: Bool

    var body: some View {
        ControlScreen(wide: wide) {
            ControlTitle(title: title, line: line, theme: theme)
            OnlyAtHomeNote(detail: AwayCopy.onlyAtHomeDetail, theme: theme)
        }
    }
}
