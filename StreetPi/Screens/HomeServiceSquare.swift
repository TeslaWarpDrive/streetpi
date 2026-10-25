import StreetPiCore
import SwiftUI

/// One service square: a dot and a single status word.
struct HomeServiceSquareView: View {
    var square: HomeServiceSquare
    var action: () -> Void

    @Environment(\.afterglowPalette) private var palette

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: AfterglowShape.line) {
                HStack(alignment: .center, spacing: 8) {
                    StatusDot(tone: square.tone)
                    Text(square.word)
                        .font(.headline)
                        .foregroundStyle(palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Label {
                    Text(square.title)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: square.symbol)
                        .accessibilityHidden(true)
                }
                .font(.subheadline)
                .foregroundStyle(palette.secondary)
                .labelStyle(.titleAndIcon)
            }
            .padding(AfterglowShape.tilePadding)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(
                palette.panelRaised,
                in: RoundedRectangle(cornerRadius: AfterglowShape.tile, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: AfterglowShape.tile, style: .continuous)
                    .strokeBorder(palette.hairline, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(square.spoken)
    }
}
