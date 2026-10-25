import SwiftUI

/// Gallery sample of the floating tab bar. It does not change the app's tabs.
struct GalleryTabBar: View {
    @Environment(\.afterglowPalette) private var palette
    @Environment(\.afterglowGate) private var gate
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selected = GalleryTab.house

    var body: some View {
        Group {
            if gate.usesSolidPlate {
                padded
                    .background(palette.panelRaised, in: Capsule())
                    .overlay { Capsule().strokeBorder(palette.hairline, lineWidth: 1) }
            } else if #available(iOS 26, *) {
                padded
                    .glassEffect(.regular, in: Capsule())
            } else {
                padded
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay { Capsule().strokeBorder(palette.hairline, lineWidth: 1) }
            }
        }
        .shadow(color: Color.black.opacity(0.28), radius: 12, y: 6)
    }

    private var padded: some View {
        bar
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .overlay(alignment: .top) {
                Capsule()
                    .fill(Color.white.opacity(0.22))
                    .frame(height: 1)
                    .padding(.horizontal, 22)
                    .padding(.top, 1)
                    .accessibilityHidden(true)
            }
    }

    private var bar: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: AfterglowShape.tight) {
                    tabs
                }
            } else {
                HStack(spacing: 0) {
                    tabs
                }
            }
        }
    }

    private var tabs: some View {
        ForEach(GalleryTab.allCases) { tab in
            GalleryTabButton(tab: tab, selected: tab == selected) {
                selected = tab
            }
        }
    }
}
