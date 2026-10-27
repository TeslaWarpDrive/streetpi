import StreetPiCore
import SwiftUI

/// Stopped, lookups, and the last hour. Each big number has its own line and opens an explainer.
struct CountTiles: View {
    var share: LookupShare
    var onExplain: (NumberExplainer) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if dynamicTypeSize >= .xLarge {
            VStack(alignment: .leading, spacing: BoardColumns<EmptyView, EmptyView>.phoneGap) {
                tiles
            }
        } else {
            HStack(alignment: .top, spacing: BoardColumns<EmptyView, EmptyView>.phoneGap) {
                tiles
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var tiles: some View {
        CountTile(number: share.stopped.formatted(), line: "ads and trackers stopped") {
            onExplain(AdBlockerCopy.stopped(share))
        }
        CountTile(number: share.lookups.formatted(), line: "lookups in 24 hours") {
            onExplain(AdBlockerCopy.lookups(share))
        }
        CountTile(number: share.lastHourStopped.map { $0.formatted() } ?? "—", line: "stopped in the last hour") {
            onExplain(AdBlockerCopy.lastHour(share))
        }
    }
}

struct CountTile: View {
    var number: String
    var line: String
    var action: () -> Void

    @Environment(\.afterglowPalette) private var palette

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                Text(number)
                    .font(.title2.monospaced().bold())
                    .foregroundStyle(palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(line)
                    .font(.footnote)
                    .foregroundStyle(palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(AfterglowShape.line)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(palette.panel, in: RoundedRectangle(cornerRadius: AfterglowShape.tile, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(number) \(line)")
        .accessibilityHint("Explains this number.")
    }
}
