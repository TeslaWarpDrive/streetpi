import SwiftUI

/// A monitor square. The check or cross keeps the meaning when color is not enough.
struct MonitorSquare: View {
    var up: Bool
    var side: CGFloat

    @Environment(\.afterglowPalette) private var palette

    var body: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(up ? palette.calm : palette.problem)
            .frame(width: side, height: side)
            .overlay {
                Image(systemName: up ? "checkmark" : "xmark")
                    .font(.caption.bold())
                    .foregroundStyle(palette.ground)
                    .accessibilityHidden(true)
            }
            .accessibilityHidden(true)
    }
}
