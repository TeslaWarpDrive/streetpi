import SwiftUI

struct AfterglowButton: View {
    var title: String
    var systemImage: String
    var action: () -> Void

    @Environment(\.afterglowPalette) private var palette
    @Environment(\.afterglowGate) private var gate
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if gate.usesSolidPlate {
            labeledButton
                .background(palette.panelRaised, in: Capsule())
                .overlay {
                    Capsule().strokeBorder(palette.hairlineInteractive, lineWidth: 1)
                }
        } else if #available(iOS 26, *) {
            labeledButton
                .glassEffect(.regular.interactive(), in: Capsule())
        } else {
            labeledButton
                .background(.ultraThinMaterial, in: Capsule())
                .overlay {
                    Capsule().strokeBorder(palette.hairlineInteractive, lineWidth: 1)
                }
        }
    }

    private var labeledButton: some View {
        Button(action: action) {
            Label {
                Text(title)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: locksToOneLine, vertical: true)
            } icon: {
                Image(systemName: systemImage)
                    .foregroundStyle(palette.accent)
                    .accessibilityHidden(true)
            }
            .font(AfterglowType.label)
            .foregroundStyle(palette.ink)
            .labelStyle(.titleAndIcon)
            .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil, minHeight: 44, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    /// One line at normal sizes so a tight row falls back to the stack. Large type wraps the full label.
    private var locksToOneLine: Bool {
        dynamicTypeSize.isAccessibilitySize == false
    }
}
