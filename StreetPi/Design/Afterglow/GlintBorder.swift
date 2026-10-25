import SwiftUI

/// One sweep of light around a card. Reduce Motion and `streetPiStill` draw nothing,
/// so a snapshot never freezes a beam in place.
struct GlintBorder: View {
    var active: Bool
    var cornerRadius: CGFloat

    @Environment(\.afterglowPalette) private var palette
    @Environment(\.afterglowGate) private var gate
    @State private var progress: CGFloat = 0

    var body: some View {
        if showsBeam {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .trim(from: max(0, progress - 0.18), to: progress)
                .stroke(palette.auraBlue, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .onAppear(perform: play)
                .onChange(of: active) { _, isActive in
                    if isActive {
                        play()
                    }
                }
        }
    }

    private var showsBeam: Bool {
        active && gate.holdsMotion
    }

    private func play() {
        guard showsBeam else {
            progress = 0
            return
        }
        progress = 0
        withAnimation(.linear(duration: AfterglowMotion.slow)) {
            progress = 1
        } completion: {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                progress = 0
            }
        }
    }
}
