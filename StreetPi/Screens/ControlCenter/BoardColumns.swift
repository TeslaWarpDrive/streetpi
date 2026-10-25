import SwiftUI

/// Two tiles side by side when the row fits. At the largest type, and in a narrow window, they stack.
struct BoardColumns<Leading: View, Trailing: View>: View {
    var wide: Bool
    @ViewBuilder var leading: () -> Leading
    @ViewBuilder var trailing: () -> Trailing

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if wide, dynamicTypeSize.isAccessibilitySize == false {
            HStack(alignment: .top, spacing: AfterglowShape.line) {
                leading()
                    .frame(maxWidth: .infinity, alignment: .leading)
                trailing()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            stacked
        }
    }

    private var stacked: some View {
        VStack(alignment: .leading, spacing: AfterglowShape.line) {
            leading()
            trailing()
        }
    }
}
