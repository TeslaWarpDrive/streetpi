import StreetPiCore
import SwiftUI

/// Existing alerts, presented from the House bell.
struct AlertsSheet: View {
    var alerts: [HouseAlert]
    var note: String?
    var theme: StreetTheme
    var wide: Bool
    var onClose: () -> Void

    var body: some View {
        NavigationStack {
            AlertsScreen(alerts: alerts, note: note, theme: theme, wide: wide)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done", action: onClose)
                    }
                }
        }
        .safeAreaPadding(.bottom, TabClearance.sheet)
        .presentationDragIndicator(.visible)
        .presentationBackground(theme.background)
    }
}
