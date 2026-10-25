import StreetPiCore
import SwiftUI

/// A status dot with a soft glow. The word or symbol beside it carries the meaning.
struct StatusDot: View {
    var tone: PlainEnglishStatus.Tone

    @Environment(\.afterglowPalette) private var palette
    @Environment(\.afterglowGate) private var gate
    @ScaledMetric(relativeTo: .body) private var side = 8

    var body: some View {
        Circle()
            .fill(palette.tone(tone))
            .frame(width: side, height: side)
            .shadow(color: palette.tone(tone).opacity(gate.holdsMotion ? 0.9 : 0.7), radius: 5)
            .accessibilityHidden(true)
    }
}
