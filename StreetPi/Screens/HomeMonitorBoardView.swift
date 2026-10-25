import StreetPiCore
import SwiftUI

struct HomeMonitorBoardView: View {
    var board: HomeMonitorBoard
    var onOpen: (HouseGroup) -> Void

    @Environment(\.afterglowPalette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: AfterglowShape.line) {
            Text(board.title)
                .font(.headline)
                .foregroundStyle(palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(board.summary)
                .font(.title2.bold())
                .foregroundStyle(palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(board.line)
                .font(.body)
                .foregroundStyle(palette.secondary)
                .fixedSize(horizontal: false, vertical: true)
            AfterglowTileGrid(
                spacing: AfterglowShape.line,
                minimumColumnWidth: dynamicTypeSize.isAccessibilitySize ? 10_000 : 108,
                maximumColumns: dynamicTypeSize.isAccessibilitySize ? 1 : 4
            ) {
                ForEach(board.monitors) { monitor in
                    HomeMonitorSquare(monitor: monitor) {
                        onOpen(monitor.group)
                    }
                }
            }
        }
        .padding(AfterglowShape.tilePadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.panel, in: RoundedRectangle(cornerRadius: AfterglowShape.panel, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AfterglowShape.panel, style: .continuous)
                .strokeBorder(palette.hairline, lineWidth: 1)
        }
    }
}

struct HomeMonitorSquare: View {
    var monitor: HomeMonitor
    var action: () -> Void

    @Environment(\.afterglowPalette) private var palette

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 8) {
                    StatusDot(tone: monitor.tone)
                    Text(monitor.word)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(monitor.name)
                    .font(.body)
                    .foregroundStyle(palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(palette.panelRaised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(monitor.spoken)
    }
}
