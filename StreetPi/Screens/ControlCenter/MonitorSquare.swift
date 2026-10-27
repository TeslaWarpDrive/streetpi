import SwiftUI

/// A rounded monitor square. Up is a filled green square. Down is a red outline,
/// so the shape changes too. The count line beside the row carries the words.
struct MonitorSquare: View {
    var up: Bool

    @Environment(\.afterglowPalette) private var palette

    var body: some View {
        Group {
            if up {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(palette.calm)
            } else {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .strokeBorder(palette.problem, lineWidth: 2)
            }
        }
        .accessibilityHidden(true)
    }
}
