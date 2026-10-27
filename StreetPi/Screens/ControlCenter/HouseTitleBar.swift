import SwiftUI

/// The House title, the bell, and Settings. The buttons sit on the title row,
/// and move to their own row at accessibility sizes so they never crowd the title.
struct HouseTitleBar: View {
    var alertCount: Int
    var onAlerts: () -> Void
    var onSettings: () -> Void

    @Environment(\.afterglowPalette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: AfterglowShape.line) {
                title
                buttons
            }
        } else {
            HStack(alignment: .center, spacing: AfterglowShape.line) {
                title
                buttons
            }
        }
    }

    private var title: some View {
        Text("Pi Stats")
            .font(dynamicTypeSize.isAccessibilitySize ? .largeTitle.bold() : .title.bold())
            .foregroundStyle(palette.ink)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }

    private var buttons: some View {
        ChromeButtonPair(
            first: AlertsBell(alertCount: alertCount, action: onAlerts),
            second: SettingsChromeButton(action: onSettings)
        )
        .fixedSize(horizontal: true, vertical: true)
    }
}
