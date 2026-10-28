import SwiftUI

/// Two tiles side by side, ending on the same line. The phone hero stays two-up, so it is not one tall card.
/// At accessibility sizes the two tiles stack on every device, so big numbers keep the full width.
struct BoardColumns<Leading: View, Trailing: View>: View {
    var wide: Bool
    @ViewBuilder var leading: () -> Leading
    @ViewBuilder var trailing: () -> Trailing

    /// The gutter between Home tiles on a phone, across and down.
    static var phoneGap: CGFloat { 10 }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: Self.phoneGap) {
                leading()
                trailing()
            }
        } else {
            HStack(alignment: .top, spacing: wide ? AfterglowShape.line : Self.phoneGap) {
                leading()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                trailing()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}
