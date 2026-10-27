import StreetPiCore
import SwiftUI

/// Today on the iPad split. The same view the Home card opens and the Ad blocker tab starts on.
struct DNSToday: View {
    var desk: DNSDesk
    var theme: StreetTheme
    var wide: Bool
    var onAction: (HouseholdAction) -> Void

    var body: some View {
        AfterglowScope(paintsGround: false) {
            AdBlockerOverview(desk: desk, theme: theme, wide: wide, onAction: onAction)
        }
    }
}
