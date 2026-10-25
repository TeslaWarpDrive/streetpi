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
        HStack(alignment: .center, spacing: 6) {
            Image(systemName: symbol ?? AfterglowSymbol.status(tone))
                .shadow(color: palette.tone(tone).opacity(0.75), radius: 5)
                .accessibilityHidden(true)
            Text(title)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(AfterglowType.chip)
        .foregroundStyle(palette.tone(tone))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(minHeight: 32)
        .background(palette.tone(tone).opacity(0.16), in: Capsule())
        .overlay {
            Capsule().strokeBorder(palette.hairline, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }
}
