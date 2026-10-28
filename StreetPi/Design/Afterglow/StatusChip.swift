import StreetPiCore
import SwiftUI

struct StatusChip: View {
    var title: String
    var tone: PlainEnglishStatus.Tone
    var symbol: String?

    @Environment(\.afterglowPalette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(title: String, tone: PlainEnglishStatus.Tone, symbol: String? = nil) {
        self.title = title
        self.tone = tone
        self.symbol = symbol
    }

    var body: some View {
        label
            .font(AfterglowType.chip)
            .foregroundStyle(palette.tone(tone))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(minHeight: 44, alignment: .leading)
            .background(palette.tone(tone).opacity(0.16), in: Capsule())
            .overlay {
                Capsule().strokeBorder(palette.hairline, lineWidth: 1)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(title)
    }

    /// Largest type scrolls the words on one line so the pill does not tower over the headline.
    @ViewBuilder
    private var label: some View {
        if dynamicTypeSize.isAccessibilitySize {
            ScrollView(.horizontal) {
                oneLine
            }
            .scrollIndicators(.visible)
        } else {
            // Chip words are short. One line keeps the symbol beside the word.
            oneLine
        }
    }

    private var oneLine: some View {
        HStack(alignment: .center, spacing: 6) {
            mark
            Text(title)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: true)
        }
    }

    private var mark: some View {
        Image(systemName: symbol ?? AfterglowSymbol.status(tone))
            .shadow(color: palette.tone(tone).opacity(0.75), radius: 5)
            .accessibilityHidden(true)
    }
}
