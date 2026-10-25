import StreetPiCore
import SwiftUI

/// Status pill and when the reading was checked. The accent word keeps the Aurora sheen.
struct HomeStatusRow: View {
    var board: HomeBoard

    @Environment(\.afterglowPalette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: AfterglowShape.line) {
            pillRow
            if let detail = board.statusDetail, detail.isEmpty == false {
                Text(detail)
                    .font(.body)
                    .foregroundStyle(palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, glowBand)
        .background(alignment: .top) {
            AuraView(tone: board.statusTone)
                .frame(height: glowBand + 28)
                .frame(maxWidth: .infinity)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    private var glowBand: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 12 : 56
    }

    private var pillRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: AfterglowShape.line) {
                pill
                Spacer(minLength: AfterglowShape.line)
                checked
            }
            VStack(alignment: .leading, spacing: AfterglowShape.tight) {
                pill
                checked
            }
        }
    }

    private var pill: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            StatusDot(tone: board.statusTone)
            HeadlineWords(
                title: board.statusTitle,
                accentWord: board.statusAccent,
                font: dynamicTypeSize.isAccessibilitySize ? .title2.bold() : .title3.bold()
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.panelRaised, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(palette.tone(board.statusTone).opacity(0.45), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var checked: some View {
        Text(board.checkedLine)
            .font(.subheadline)
            .foregroundStyle(palette.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
