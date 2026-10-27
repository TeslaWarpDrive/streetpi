import StreetPiCore
import SwiftUI

/// A solid Aurora panel. The ad blocker tile is a solid lavender fill. Other tiles stay on the plate.
/// It fills the height its row offers, so two panels side by side end on the same line.
struct BoardPanel<Content: View>: View {
    var lavender: Bool = false
    var inset: CGFloat = AfterglowShape.line
    @ViewBuilder var content: Content

    @Environment(\.afterglowPalette) private var palette

    var body: some View {
        content
            .padding(inset)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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

/// Icon in a round chip, bold title, and a muted detail. Used by the lower Home tiles.
/// At accessibility sizes the chip sits above the words, so the words keep the full width.
struct HouseGlance<Detail: View>: View {
    var title: String
    var symbol: String
    @ViewBuilder var detail: () -> Detail

    @Environment(\.afterglowPalette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: AfterglowShape.tight) {
                    GlanceChip(symbol: symbol)
                    words
                }
            } else {
                HStack(alignment: .center, spacing: AfterglowShape.line) {
                    GlanceChip(symbol: symbol)
                    words
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var words: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            detail()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A round icon chip on the panel. It grows with the text size.
struct GlanceChip: View {
    var symbol: String

    @Environment(\.afterglowPalette) private var palette
    @ScaledMetric(relativeTo: .body) private var side: CGFloat = 40

    var body: some View {
        Image(systemName: symbol)
            .font(.body)
            .foregroundStyle(palette.accent)
            .frame(width: side, height: side)
            .background(palette.panelRaised, in: Circle())
            .accessibilityHidden(true)
    }
}
