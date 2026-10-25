import SwiftUI

/// The House title, the bell, and Settings. The buttons stay on the title row.
struct HouseTitleBar: View {
    var alertCount: Int
    var onAlerts: () -> Void
    var onSettings: () -> Void

    @Environment(\.afterglowPalette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(alignment: .center, spacing: AfterglowShape.line) {
            Text("Pi Stats")
                .font(dynamicTypeSize.isAccessibilitySize ? .largeTitle.bold() : .title.bold())
                .foregroundStyle(palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
            ChromeButtonPair(
                first: AlertsBell(alertCount: alertCount, action: onAlerts),
                second: SettingsChromeButton(action: onSettings)
            )
            .fixedSize(horizontal: true, vertical: true)
        }
    }
}
