import SwiftUI

struct KickerLabel: View {
    var text: String

    @Environment(\.afterglowPalette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            ScrollView(.horizontal) {
                label
                    .fixedSize(horizontal: true, vertical: true)
            }
            .scrollIndicators(.visible)
            .accessibilityAddTraits(.isHeader)
        } else {
            label
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        }
    }

    private var label: some View {
        Text(text)
            .font(AfterglowType.kicker)
            .tracking(dynamicTypeSize.isAccessibilitySize ? 0 : 1.4)
            .foregroundStyle(palette.secondary)
    }
}
