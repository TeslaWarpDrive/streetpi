import SwiftUI

/// The headline. The accent word carries the Aurora sheen. The rest stays ink.
///
/// Joining `Text` runs drops a gradient and the word paints as the label color,
/// which is white on a dark phone. Each word is its own view, and the accent
/// word masks a real Aurora gradient so the sheen survives layout and snapshots.
struct HeadlineWords: View {
    var title: String
    var accentWord: String

    @Environment(\.afterglowPalette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        WordFlow(spacing: dynamicTypeSize.isAccessibilitySize ? 6 : 8) {
            ForEach(Array(tokens.enumerated()), id: \.offset) { _, token in
                styled(token)
            }
        }
        .font(dynamicTypeSize.isAccessibilitySize ? AfterglowType.title : AfterglowType.display)
        .tracking(dynamicTypeSize.isAccessibilitySize ? 0 : -0.5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
    }

    private var tokens: [String] {
        title.split(separator: " ").map(String.init)
    }

    @ViewBuilder
    private func styled(_ token: String) -> some View {
        if isAccent(token) {
            SheenWord(text: token)
        } else {
            Text(token)
                .foregroundStyle(palette.ink)
                .accessibilityHidden(true)
        }
    }

    private func isAccent(_ token: String) -> Bool {
        guard accentWord.isEmpty == false else { return false }
        let stripped = token.trimmingCharacters(in: .punctuationCharacters)
        return stripped.caseInsensitiveCompare(accentWord) == .orderedSame
    }
}

/// Aurora stops painted through the glyphs. A gradient style on `Text` does not hold.
struct SheenWord: View {
    var text: String
    var minimumScale: CGFloat = 0.5

    @Environment(\.afterglowPalette) private var palette

    var body: some View {
        Text(text)
            .foregroundStyle(.clear)
            .lineLimit(1)
            .minimumScaleFactor(minimumScale)
            .overlay {
                LinearGradient(
                    colors: [palette.auraTeal, palette.auraBlue, palette.auraViolet, palette.auraPink],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .mask {
                    Text(text)
                        .lineLimit(1)
                        .minimumScaleFactor(minimumScale)
                }
            }
            .compositingGroup()
            .clipped()
            .accessibilityHidden(true)
    }
}

/// Wraps headline words onto the next line instead of squeezing them together.
struct WordFlow: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let limit = usableWidth(proposal.width)
        let lines = rows(maxWidth: limit, subviews: subviews)
        let gaps = lineGap * CGFloat(max(0, lines.count - 1))
        let height = lines.reduce(0) { $0 + $1.height } + gaps
        let width = lines.map(\.width).max() ?? 0
        return CGSize(width: min(width, limit), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let lines = rows(maxWidth: bounds.width, subviews: subviews)
        var originY = bounds.minY
        for line in lines {
            var originX = bounds.minX
            for index in line.indexes {
                let width = line.widths[index] ?? 0
                subviews[index].place(
                    at: CGPoint(x: originX, y: originY),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(width: width, height: nil)
                )
                originX += width + spacing
            }
            originY += line.height + lineGap
        }
    }

    private var lineGap: CGFloat { 4 }

    private func usableWidth(_ proposed: CGFloat?) -> CGFloat {
        guard let proposed, proposed.isFinite, proposed > 0 else { return 10_000 }
        return proposed
    }

    private func rows(maxWidth: CGFloat, subviews: Subviews) -> [WordRow] {
        let limit = maxWidth.isFinite && maxWidth > 0 ? maxWidth : 10_000
        var lines: [WordRow] = []
        var indexes: [Int] = []
        var widths: [Int: CGFloat] = [:]
        var lineWidth: CGFloat = 0
        var lineHeight: CGFloat = 0

        for index in subviews.indices {
            let ideal = subviews[index].sizeThatFits(.unspecified)
            let remaining = indexes.isEmpty ? limit : limit - lineWidth - spacing
            let width = min(max(ideal.width, 0), limit)
            let fits = indexes.isEmpty || ideal.width <= max(0, remaining)
            if fits == false {
                lines.append(WordRow(indexes: indexes, widths: widths, width: lineWidth, height: lineHeight))
                indexes = []
                widths = [:]
                lineWidth = 0
                lineHeight = 0
            }
            let used = min(width, limit)
            let measured = subviews[index].sizeThatFits(ProposedViewSize(width: used, height: nil))
            indexes.append(index)
            widths[index] = used
            lineWidth += indexes.count == 1 ? used : spacing + used
            lineHeight = max(lineHeight, measured.height)
        }
        if indexes.isEmpty == false {
            lines.append(WordRow(indexes: indexes, widths: widths, width: lineWidth, height: lineHeight))
        }
        return lines
    }
}

private struct WordRow {
    var indexes: [Int]
    var widths: [Int: CGFloat]
    var width: CGFloat
    var height: CGFloat
}
