import StreetPiCore
import SwiftUI

/// One member of a list: a name and its plain status word.
struct StatusLine: Identifiable, Equatable {
    var id: String
    var name: String
    var word: String
    var tone: PlainEnglishStatus.Tone

    /// Status words from the status page and the charts. Anything unfamiliar asks for a look.
    static func tone(forWord word: String) -> PlainEnglishStatus.Tone {
        switch word.lowercased() {
        case "up", "running", "ready", "copied", "up to date", "blocking", "answering":
            .calm
        case "down", "not responding", "stopped", "exited":
            .problem
        default:
            .attention
        }
    }
}

/// How the status shows beside the name: a glowing dot and word, or a chip.
enum StatusMark {
    case dot
    case chip
}

/// Rows on one solid panel, split by hairlines. Reading text never sits on glass.
struct StatusList: View {
    var lines: [StatusLine]
    var mark: StatusMark

    @Environment(\.afterglowPalette) private var palette

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: AfterglowShape.panel, style: .continuous)
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(lines.enumerated()), id: \.element.id) { index, line in
                if index > 0 {
                    Rectangle()
                        .fill(palette.hairline)
                        .frame(height: 1)
                        .accessibilityHidden(true)
                }
                StatusListRow(line: line, mark: mark)
            }
        }
        .padding(.horizontal, AfterglowShape.panelPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.panel, in: shape)
        .overlay { shape.strokeBorder(palette.hairline, lineWidth: 1) }
    }
}

private struct StatusListRow: View {
    var line: StatusLine
    var mark: StatusMark

    @Environment(\.afterglowPalette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                stacked
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: AfterglowShape.line) {
                        name
                        Spacer(minLength: AfterglowShape.line)
                        status
                    }
                    stacked
                }
            }
        }
        .padding(.vertical, AfterglowShape.line)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(line.name), \(line.word)")
    }

    private var stacked: some View {
        VStack(alignment: .leading, spacing: AfterglowShape.tight) {
            name
            status
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var name: some View {
        Text(line.name)
            .font(.headline)
            .foregroundStyle(palette.ink)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var status: some View {
        switch mark {
        case .dot:
            HStack(alignment: .center, spacing: AfterglowShape.tight) {
                StatusDot(tone: line.tone)
                Text(line.word)
                    .font(AfterglowType.label)
                    .foregroundStyle(palette.tone(line.tone))
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .chip:
            // The short word claims its one-line width first; the longer name wraps instead.
            StatusChip(title: line.word, tone: line.tone)
                .layoutPriority(1)
        }
    }
}
