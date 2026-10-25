import SwiftUI

/// Injects the Aurora palette and motion gate, and paints the ground.
struct AfterglowScope<Content: View>: View {
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.streetPiStill) private var still
    @ViewBuilder var content: Content

    var body: some View {
        let palette = AfterglowPalette.resolve(contrast: contrast)
        let gate = AfterglowMotionGate(
            reduceMotion: reduceMotion,
            still: still,
            reduceTransparency: reduceTransparency
        )
        content
            .environment(\.afterglowPalette, palette)
            .environment(\.afterglowGate, gate)
            .background {
                ZStack {
                    palette.ground
                    GroundGrain()
                        .opacity(0.07)
                        .blendMode(.overlay)
                        .accessibilityHidden(true)
                }
            }
    }
}
