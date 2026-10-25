import SwiftUI

enum GalleryTab: String, CaseIterable, Identifiable {
    case house
    case adBlocker
    case pi
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .house:
            "House"
        case .adBlocker:
            "Ad blocker"
        case .pi:
            "Pi"
        case .settings:
            "Settings"
        }
    }

    var symbol: String {
        switch self {
        case .house:
            "house.fill"
        case .adBlocker:
            "shield.lefthalf.filled"
        case .pi:
            "cpu"
        case .settings:
            "gearshape"
        }
    }
}

struct GalleryTabButton: View {
    var tab: GalleryTab
    var selected: Bool
    var action: () -> Void

    @Environment(\.afterglowPalette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button(action: action) {
            label
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.horizontal, 6)
                .padding(.vertical, 6)
                .background {
                    if selected {
                        Capsule().fill(palette.accent.opacity(0.16))
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var label: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                tabLabel
                    .labelStyle(.titleAndIcon)
            } else {
                tabLabel
                    .labelStyle(.vertical)
            }
        }
        .font(AfterglowType.label)
        .foregroundStyle(selected ? palette.accent : palette.secondary)
    }

    private var tabLabel: some View {
        Label {
            Text(tab.title)
                .multilineTextAlignment(dynamicTypeSize.isAccessibilitySize ? .leading : .center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(
                    maxWidth: .infinity,
                    alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .center
                )
        } icon: {
            Image(systemName: tab.symbol)
                .accessibilityHidden(true)
        }
    }
}

private struct VerticalLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: 3) {
            configuration.icon
            configuration.title
        }
    }
}

extension LabelStyle where Self == VerticalLabelStyle {
    static var vertical: VerticalLabelStyle { VerticalLabelStyle() }
}
