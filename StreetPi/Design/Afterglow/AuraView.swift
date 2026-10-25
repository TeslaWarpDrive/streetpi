import simd
import StreetPiCore
import SwiftUI

/// Aurora wash behind the headline. Rings and the accent word use this same family.
/// `streetPiStill` and Reduce Motion paint a fixed wash, so snapshots never render
/// `MeshGradient` or `TimelineView`. The moving wash is a native mesh, not a copied shader.
struct AuraView: View {
    var tone: PlainEnglishStatus.Tone

    @Environment(\.afterglowPalette) private var palette
    @Environment(\.afterglowGate) private var gate

    var body: some View {
        Group {
            if breathes {
                TimelineView(.animation(minimumInterval: 1.0 / 8.0, paused: false)) { timeline in
                    let phase = timeline.date.timeIntervalSinceReferenceDate
                        .truncatingRemainder(dividingBy: AfterglowMotion.breathe) / AfterglowMotion.breathe
                    MeshGradient(
                        width: 3,
                        height: 3,
                        points: points(phase: phase),
                        colors: meshColors
                    )
                }
            } else {
                stillWash
            }
        }
        .accessibilityHidden(true)
    }

    private var breathes: Bool {
        gate.holdsMotion && !ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    /// Bright at the top, so a short phone headline still shows the glow above the plate.
    private var stillWash: some View {
        ZStack {
            blob(palette.auraTeal, amount: 0.72, centerX: 0.18, centerY: 0.08, radius: 180)
            blob(palette.auraBlue, amount: 0.68, centerX: 0.78, centerY: 0.02, radius: 190)
            blob(palette.auraViolet, amount: 0.55, centerX: 0.42, centerY: 0.42, radius: 160)
            blob(palette.auraPink, amount: 0.42, centerX: 0.88, centerY: 0.36, radius: 140)
            toneWash
        }
    }

    @ViewBuilder
    private var toneWash: some View {
        switch tone {
        case .calm:
            EmptyView()
        case .attention:
            blob(palette.attention, amount: 0.45, centerX: 0.3, centerY: 0.12, radius: 150)
        case .problem:
            blob(palette.problem, amount: 0.5, centerX: 0.62, centerY: 0.1, radius: 150)
        }
    }

    private func blob(
        _ color: Color,
        amount: Double,
        centerX: CGFloat,
        centerY: CGFloat,
        radius: CGFloat
    ) -> some View {
        RadialGradient(
            colors: [palette.wash(color, amount: amount), palette.wash(color, amount: 0)],
            center: UnitPoint(x: centerX, y: centerY),
            startRadius: 0,
            endRadius: radius
        )
    }

    private var meshColors: [Color] {
        let ground = palette.ground
        let teal = palette.wash(palette.auraTeal, amount: 0.7)
        let blue = palette.wash(palette.auraBlue, amount: 0.65)
        let violet = palette.wash(palette.auraViolet, amount: 0.55)
        let pink = palette.wash(palette.auraPink, amount: 0.4)
        switch tone {
        case .calm:
            return [ground, blue, ground, teal, violet, blue, ground, pink, ground]
        case .attention:
            let lead = palette.wash(palette.attention, amount: 0.6)
            return [ground, lead, ground, blue, lead, violet, ground, pink, ground]
        case .problem:
            let lead = palette.wash(palette.problem, amount: 0.65)
            return [ground, lead, ground, pink, lead, violet, ground, blue, ground]
        }
    }

    private func points(phase: Double) -> [SIMD2<Float>] {
        let drift = Float(sin(phase * 2 * .pi)) * 0.04
        return [
            SIMD2(0, 0), SIMD2(0.5, 0), SIMD2(1, 0),
            SIMD2(0, 0.5 + drift), SIMD2(0.5 + drift, 0.42 - drift), SIMD2(1, 0.5 - drift),
            SIMD2(0, 1), SIMD2(0.5, 1), SIMD2(1, 1),
        ]
    }
}
