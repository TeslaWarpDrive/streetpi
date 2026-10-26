import StreetPiCore
import SwiftUI

/// A solid Aurora panel. The ad blocker tile is a solid lavender fill. Other tiles stay on the plate.
struct BoardPanel<Content: View>: View {
    var lavender: Bool = false
    var inset: CGFloat = 6
    @ViewBuilder var content: Content

    @Environment(\.afterglowPalette) private var palette

    var body: some View {
        content
            .padding(inset)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: AfterglowShape.panel, style: .continuous)
                    .fill(lavender ? palette.accent : palette.panel)
            }
            .overlay {
                if lavender == false {
                    RoundedRectangle(cornerRadius: AfterglowShape.panel, style: .continuous)
                        .strokeBorder(palette.hairline, lineWidth: 1)
                }
            }
    }
}

/// Title and one short value. The longer sentence stays in the spoken label.
struct CompactFact: View {
    var title: String
    var value: String
    var tone: PlainEnglishStatus.Tone?

    @Environment(\.afterglowPalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(palette.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if let tone {
                    StatusDot(tone: tone)
                }
                FittingText(
                    text: value,
                    color: palette.ink,
                    style: .subheadline,
                    weight: .bold,
                    identifier: "compact-value",
                    breaksWords: false
                )
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Icon, bold title, and a muted detail. Used by the four lower Home tiles.
struct HouseGlance<Detail: View>: View {
    var title: String
    var symbol: String
    @ViewBuilder var detail: () -> Detail

    @Environment(\.afterglowPalette) private var palette

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: symbol)
                .font(.footnote)
                .foregroundStyle(palette.accent)
                .frame(width: 22, height: 22)
                .background(palette.accent.opacity(0.16), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.footnote.bold())
                    .foregroundStyle(palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                detail()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
