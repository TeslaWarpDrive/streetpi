import SwiftUI

/// Reading text sits on a solid plate. Glass, when it is allowed, is the rim around that plate.
struct AfterglowPlate<Content: View>: View {
    var cornerRadius: CGFloat
    var interactive: Bool
    var contentPadding: CGFloat
    @ViewBuilder var content: Content

    @Environment(\.afterglowPalette) private var palette
    @Environment(\.afterglowGate) private var gate
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let inner = RoundedRectangle(
            cornerRadius: max(8, cornerRadius - 6),
            style: .continuous
        )
        let plateOpacity = gate.usesSolidPlate ? 1.0 : 0.94
        let stacked = content
            .padding(contentPadding)
            .background(palette.panelRaised.opacity(plateOpacity), in: inner)
            .padding(AfterglowShape.plateInset)

        Group {
            if gate.usesSolidPlate {
                stacked
                    .background(palette.panel, in: shape)
                    .overlay { shape.strokeBorder(hairline, lineWidth: 1) }
            } else if #available(iOS 26, *) {
                glassStacked(stacked, shape: shape)
            } else {
                stacked
                    .background(.ultraThinMaterial, in: shape)
                    .overlay { shape.strokeBorder(hairline, lineWidth: 1) }
            }
        }
        .overlay(alignment: .top) {
            Capsule()
                .fill(Color.white.opacity(colorScheme == .dark ? 0.2 : 0.7))
                .frame(height: 1)
                .padding(.horizontal, cornerRadius)
                .padding(.top, 1)
                .accessibilityHidden(true)
        }
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.1), radius: 12, y: 6)
    }

    private var hairline: Color {
        interactive ? palette.hairlineInteractive : palette.hairline
    }

    @ViewBuilder
    @available(iOS 26, *)
    private func glassStacked<PlateContent: View>(_ stacked: PlateContent, shape: RoundedRectangle) -> some View {
        if interactive {
            stacked
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
                .overlay { shape.strokeBorder(hairline, lineWidth: 1) }
        } else {
            stacked
                .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
                .overlay { shape.strokeBorder(hairline, lineWidth: 1) }
        }
    }
}
