import SwiftUI

/// The House title, the bell, and Settings.
struct HouseTitleBar: View {
    var alertCount: Int
    var onAlerts: () -> Void
    var onSettings: () -> Void

    @Environment(\.afterglowPalette) private var palette

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: AfterglowShape.line) {
                title(wraps: false)
                Spacer(minLength: AfterglowShape.line)
                controls
            }
            VStack(alignment: .leading, spacing: AfterglowShape.line) {
                title(wraps: true)
                controls
            }
        }
    }

    private func title(wraps: Bool) -> some View {
        Text("Pi Stats")
            .font(.largeTitle.bold())
            .foregroundStyle(palette.ink)
            .lineLimit(wraps ? nil : 1)
            .fixedSize(horizontal: wraps == false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }

    private var controls: some View {
        ChromeButtonPair(
            first: SettingsChromeButton(action: onSettings),
            second: AlertsBell(alertCount: alertCount, action: onAlerts)
        )
    }
}
