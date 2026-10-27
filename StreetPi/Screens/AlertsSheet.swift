import StreetPiCore
import SwiftUI

/// Existing alerts, presented from the House bell.
/// A sheet does not sit inside the House scope, so it brings its own Aurora palette and motion gate.
struct AlertsSheet: View {
    var alerts: [HouseAlert]
    var note: String?
    var theme: StreetTheme
    var wide: Bool
    var onClose: () -> Void

    var body: some View {
        NavigationStack {
            AfterglowScope(paintsGround: false) {
                AlertsScreen(alerts: alerts, note: note, theme: theme, wide: wide)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onClose()
                    }
                }
            }
        }
        .presentationDragIndicator(.visible)
        .presentationBackground(theme.background)
    }
}
