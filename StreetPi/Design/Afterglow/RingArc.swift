import SwiftUI

/// Glowing ring arc. The stroke uses the Aurora stops.
struct RingArc: View {
    var fraction: Double

    @Environment(\.afterglowPalette) private var palette

    var body: some View {
        ZStack {
            Circle()
                .stroke(palette.hairline, lineWidth: AfterglowShape.arcWidth)
            arc(lineWidth: AfterglowShape.arcWidth)
                .blur(radius: 3)
                .opacity(0.55)
            arc(lineWidth: AfterglowShape.arcWidth)
            cap
        }
        .accessibilityHidden(true)
    }

    private var clamped: Double {
        min(max(fraction, 0), 1)
    }

    private func arc(lineWidth: CGFloat) -> some View {
        let style = StrokeStyle(lineWidth: lineWidth, lineCap: .round)
        return Circle()
            .trim(from: 0, to: clamped)
            .stroke(strokeColor, style: style)
            .rotationEffect(.degrees(-90))
    }

    private var strokeColor: LinearGradient {
        ringGradient
    }

    private var ringGradient: LinearGradient {
        LinearGradient(
            colors: [palette.auraTeal, palette.auraBlue, palette.auraViolet],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var cap: some View {
        Circle()
            .fill(Color.white.opacity(0.92))
            .frame(width: 6, height: 6)
            .shadow(color: palette.auraBlue.opacity(0.9), radius: 4)
            .offset(x: capPoint.x, y: capPoint.y)
    }

    /// Trim starts at the top after the -90° rotation. Screen y grows downward.
    private var capPoint: CGPoint {
        let degrees = -90.0 + clamped * 360.0
        let radians = degrees * Double.pi / 180
        let radius = (AfterglowShape.ring - AfterglowShape.arcWidth) / 2
        return CGPoint(x: cos(radians) * radius, y: sin(radians) * radius)
    }
}
