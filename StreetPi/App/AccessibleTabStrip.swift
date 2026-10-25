import SwiftUI

/// Tab labels at the largest type sizes. The system bar truncates them.
/// This strip wraps on the iPad sidebar and scrolls on the phone, so nothing is cut off.
struct AccessibleTabStrip: View {
    @Binding var selection: HouseTab
    var scrollsHorizontally: Bool

    @Environment(\.afterglowPalette) private var palette
    @Environment(\.afterglowGate) private var gate
    @Environment(\.streetPiStill) private var still

    var body: some View {
        AfterglowScope(paintsGround: false) {
            strip
        }
        .background {
            ScrollAnchor(name: "phone-tab-strip")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tabs")
    }

    private var strip: some View {
        Group {
            if scrollsHorizontally {
                ScrollView(.horizontal) {
                    HStack(alignment: .center, spacing: AfterglowShape.line) {
                        buttons
                    }
                    .padding(.horizontal, AfterglowShape.line)
                    .padding(.vertical, AfterglowShape.tight)
                }
                .scrollIndicators(.visible)
                .scrollClipDisabled(false)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: AfterglowShape.tight) {
                        buttons
                    }
                    .padding(AfterglowShape.line)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: 340)
            }
        }
        .background { plate }
    }

    private var buttons: some View {
        ForEach(HouseTab.allCases) { tab in
            AccessibleTabButton(
                tab: tab,
                selected: tab == selection,
                scrollsHorizontally: scrollsHorizontally
            ) {
                selection = tab
            }
        }
    }

    @ViewBuilder
    private var plate: some View {
        if gate.usesSolidPlate || still {
            palette.panelRaised
                .overlay { Rectangle().strokeBorder(palette.hairline, lineWidth: 1) }
        } else if #available(iOS 26, *) {
            Rectangle().fill(.clear)
                .glassEffect(.regular, in: Rectangle())
        } else {
            Rectangle().fill(.ultraThinMaterial)
                .overlay { Rectangle().strokeBorder(palette.hairline, lineWidth: 1) }
        }
    }
}

private struct AccessibleTabButton: View {
    var tab: HouseTab
    var selected: Bool
    var scrollsHorizontally: Bool
    var action: () -> Void

    @Environment(\.afterglowPalette) private var palette

    var body: some View {
        Button(action: action) {
            Label {
                Text(tab.title)
                    .lineLimit(scrollsHorizontally ? 1 : nil)
                    .multilineTextAlignment(scrollsHorizontally ? .center : .leading)
                    .fixedSize(horizontal: scrollsHorizontally, vertical: true)
                    .frame(maxWidth: scrollsHorizontally ? nil : .infinity, alignment: .leading)
            } icon: {
                Image(systemName: tab.symbol)
                    .accessibilityHidden(true)
            }
            .labelStyle(.titleAndIcon)
            .font(AfterglowType.label)
            .foregroundStyle(selected ? palette.accent : palette.secondary)
            .frame(minWidth: 44, minHeight: 44, alignment: scrollsHorizontally ? .center : .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                if selected {
                    Capsule().fill(palette.accent.opacity(0.16))
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
