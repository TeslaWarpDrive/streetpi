import SwiftUI

/// A solid Aurora panel. The ad blocker tile tints it lavender. Body copy stays on the plate.
struct BoardPanel<Content: View>: View {
    var lavender: Bool = false
    @ViewBuilder var content: Content

    @Environment(\.afterglowPalette) private var palette

    var body: some View {
        content
            .padding(AfterglowShape.tilePadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: AfterglowShape.panel, style: .continuous)
                    .fill(palette.panel)
                    .overlay {
                        if lavender {
                            RoundedRectangle(cornerRadius: AfterglowShape.panel, style: .continuous)
                                .fill(palette.accent.opacity(0.22))
                        }
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: AfterglowShape.panel, style: .continuous)
                    .strokeBorder(lavender ? palette.accent.opacity(0.7) : palette.hairline, lineWidth: 1)
            }
    }
}
