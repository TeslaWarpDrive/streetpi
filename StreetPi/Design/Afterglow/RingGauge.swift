import StreetPiCore
import SwiftUI

struct RingGauge: View {
    var label: String
    var value: String
    var spoken: String
    var fraction: Double
    var symbol: String
    var word: String?
    var tone: PlainEnglishStatus.Tone

    @Environment(\.afterglowPalette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                row
            } else {
                dial
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
    }

    private var dial: some View {
        VStack(spacing: AfterglowShape.tight) {
            ZStack {
                RingArc(fraction: fraction)
                MonoReading(text: value, emphasize: true)
            }
            .frame(width: AfterglowShape.ring, height: AfterglowShape.ring)
            .accessibilityHidden(true)
            Label {
                Text(label)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: symbol)
                    .accessibilityHidden(true)
            }
            .font(AfterglowType.label)
            .foregroundStyle(palette.secondary)
            .labelStyle(.titleAndIcon)
            .multilineTextAlignment(.center)
            if let word {
                StatusChip(title: word, tone: tone)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Stacked, so the big value never squeezes the label into a broken word.
    private var row: some View {
        VStack(alignment: .leading, spacing: AfterglowShape.tight) {
            HStack(alignment: .center, spacing: AfterglowShape.line) {
                IconChip(systemImage: symbol)
                Text(label)
                    .font(.headline)
                    .foregroundStyle(palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            MonoReading(text: value, emphasize: true)
            if let word {
                StatusChip(title: word, tone: tone)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
    }
}
