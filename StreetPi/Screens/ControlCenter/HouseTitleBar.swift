import SwiftUI

/// The House title, the bell, and Settings.
struct HouseTitleBar: View {
    var alertCount: Int
    var onAlerts: () -> Void
    var onSettings: () -> Void

    @Environment(\.afterglowPalette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            accessible
        } else {
            regular
        }
    }

    private var regular: some View {
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

    private var accessible: some View {
        VStack(alignment: .leading, spacing: AfterglowShape.line) {
            Text("Pi Stats")
                .font(.largeTitle.bold())
                .foregroundStyle(palette.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
            controlsFitting
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var controlsFitting: some View {
        ViewThatFits(in: .horizontal) {
            controls
                .fixedSize(horizontal: true, vertical: true)
            VStack(alignment: .leading, spacing: AfterglowShape.line) {
                SettingsChromeButton(action: onSettings)
                AlertsBell(alertCount: alertCount, action: onAlerts)
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
