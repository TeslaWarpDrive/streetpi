import SwiftUI

/// A small reading line for a tile. One accent color, not a second glow.
struct Sparkline: View {
    var samples: [Double]

    @Environment(\.afterglowPalette) private var palette

    var body: some View {
        Canvas { context, size in
            guard let path = line(in: size) else { return }
            var fill = path
            fill.addLine(to: CGPoint(x: size.width, y: size.height))
            fill.addLine(to: CGPoint(x: 0, y: size.height))
            fill.closeSubpath()
            context.fill(fill, with: .color(palette.accent.opacity(0.18)))
            context.stroke(
                path,
                with: .color(palette.accent),
                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
            )
        }
        .frame(height: 34)
        .accessibilityHidden(true)
    }

    private func line(in size: CGSize) -> Path? {
        guard samples.count > 1, size.width > 1, size.height > 1 else { return nil }
        let low = samples.min() ?? 0
        let high = samples.max() ?? 1
        let span = max(high - low, 0.001)
        var path = Path()
        for (index, sample) in samples.enumerated() {
            let across = CGFloat(index) / CGFloat(samples.count - 1)
            let raised = CGFloat((sample - low) / span)
            let point = CGPoint(x: size.width * across, y: size.height * (1 - raised))
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        return path
    }
}
