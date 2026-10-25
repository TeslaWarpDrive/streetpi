import StreetPiCore
import SwiftUI

/// Temperature, a Cool / Warm / Hot word, and CPU, RAM, and Disk.
struct PiBoardCard: View {
    var tile: PiTile
    var onOpen: () -> Void

    @Environment(\.afterglowPalette) private var palette

    var body: some View {
        Button(action: onOpen) {
            BoardPanel {
                VStack(alignment: .leading, spacing: 4) {
                    header
                    MeterBar(title: "CPU", fraction: tile.cpu, limit: nil)
                    MeterBar(title: "RAM", fraction: tile.memory, limit: MachineLimits.memoryAttention)
                    MeterBar(title: "Disk", fraction: tile.disk, limit: MachineLimits.diskAttention)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Pi, \(tile.temperature), \(tile.warmth). \(tile.line)")
    }

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: AfterglowShape.tight) {
                title
                temperature
                warmth
            }
            VStack(alignment: .leading, spacing: 2) {
                title
                temperature
                warmth
            }
        }
    }

    private var title: some View {
        Text("Pi")
            .font(.caption)
            .foregroundStyle(palette.secondary)
    }

    private var temperature: some View {
        Text(tile.temperature)
            .font(.system(.title3, design: .rounded).bold())
            .foregroundStyle(palette.ink)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var warmth: some View {
        Text(tile.warmth)
            .font(.subheadline.bold())
            .foregroundStyle(palette.tone(warmthTone))
            .fixedSize(horizontal: false, vertical: true)
    }

    private var warmthTone: PlainEnglishStatus.Tone {
        switch tile.warmth {
        case "Hot":
            .problem
        case "Warm":
            .attention
        default:
            .calm
        }
    }
}
