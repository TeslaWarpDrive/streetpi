import SwiftUI

/// A rounded monitor square. The count line beside the row carries the words.
struct MonitorSquare: View {
    var up: Bool
    var side: CGFloat

    @Environment(\.afterglowPalette) private var palette

    var body: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(up ? palette.calm : palette.problem)
            .frame(width: side, height: side)
            .accessibilityHidden(true)
    }
}
