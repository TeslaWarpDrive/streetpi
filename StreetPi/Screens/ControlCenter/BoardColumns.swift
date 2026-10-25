import SwiftUI

/// Two tiles side by side. The phone hero stays two-up, so it is not one tall card.
struct BoardColumns<Leading: View, Trailing: View>: View {
    var wide: Bool
    @ViewBuilder var leading: () -> Leading
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .top, spacing: wide ? AfterglowShape.block : AfterglowShape.tight) {
            leading()
                .frame(maxWidth: .infinity, alignment: .topLeading)
            trailing()
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}
