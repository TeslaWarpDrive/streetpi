import StreetPiCore
import SwiftUI

struct RoomTile: View {
    var title: String
    var detail: String
    var word: String
    var symbol: String
    var tone: PlainEnglishStatus.Tone
    var prominent: Bool = false
    var samples: [Double] = []
    var action: () -> Void

    @Environment(\.afterglowPalette) private var palette

    var body: some View {
        Button(action: action) {
            AfterglowPlate(
                cornerRadius: AfterglowShape.tile,
                interactive: true,
                contentPadding: AfterglowShape.tilePadding
            ) {
                VStack(alignment: .leading, spacing: AfterglowShape.tight) {
                    IconChip(systemImage: symbol)
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    if showsDetail {
                        MonoReading(text: detail, emphasize: prominent)
                    }
                    if samples.count > 1 {
                        Sparkline(samples: samples)
                    }
                    statusRow
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(spoken)
    }

    private var statusRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: AfterglowShape.tight) {
                mark
                Text(word)
                    .fixedSize(horizontal: true, vertical: true)
            }
            VStack(alignment: .leading, spacing: AfterglowShape.tight) {
                mark
                Text(word)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .font(AfterglowType.label)
        .foregroundStyle(palette.tone(tone))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(word)
    }

    private var mark: some View {
        HStack(spacing: AfterglowShape.tight) {
            StatusDot(tone: tone)
            Image(systemName: AfterglowSymbol.status(tone))
                .accessibilityHidden(true)
        }
    }

    private var showsDetail: Bool {
        !detail.isEmpty && detail.caseInsensitiveCompare(word) != .orderedSame
    }

    private var spoken: String {
        if showsDetail {
            "\(title), \(detail), \(word)"
        } else {
            "\(title), \(word)"
        }
    }
}
