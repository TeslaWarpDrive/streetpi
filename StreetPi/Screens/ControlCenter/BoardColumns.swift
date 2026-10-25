import SwiftUI

/// Two tiles side by side when the row fits. At the largest type, and in a narrow window, they stack.
struct BoardColumns<Leading: View, Trailing: View>: View {
    @ViewBuilder var leading: () -> Leading
    @ViewBuilder var trailing: () -> Trailing

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            stacked
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: AfterglowShape.line) {
                    leading()
                        .frame(minWidth: 128, maxWidth: .infinity, alignment: .leading)
                    trailing()
                        .frame(minWidth: 128, maxWidth: .infinity, alignment: .leading)
                }
                stacked
            }
        }
    }

    private var stacked: some View {
        VStack(alignment: .leading, spacing: AfterglowShape.line) {
            leading()
            trailing()
        }
    }
}
