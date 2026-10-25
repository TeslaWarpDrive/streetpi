import StreetPiCore
import SwiftUI

struct StatusChip: View {
    var title: String
    var tone: PlainEnglishStatus.Tone
    var symbol: String?

    @Environment(\.afterglowPalette) private var palette

    init(title: String, tone: PlainEnglishStatus.Tone, symbol: String? = nil) {
        self.title = title
        self.tone = tone
        self.symbol = symbol
    }

    var body: some View {
        fitted
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

    /// One line when it fits. Otherwise the word wraps under the symbol instead of clipping.
    private var fitted: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 6) {
                mark
                Text(title)
                    .fixedSize(horizontal: true, vertical: true)
            }
            VStack(alignment: .leading, spacing: 4) {
                mark
                Text(title)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var mark: some View {
        Image(systemName: symbol ?? AfterglowSymbol.status(tone))
            .shadow(color: palette.tone(tone).opacity(0.75), radius: 5)
            .accessibilityHidden(true)
    }
}
