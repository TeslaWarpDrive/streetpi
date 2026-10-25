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
                VStack(alignment: .leading, spacing: AfterglowShape.line) {
                    Text("Pi")
                        .font(.subheadline)
                        .foregroundStyle(palette.secondary)
                    Text(tile.temperature)
                        .font(.system(.largeTitle, design: .rounded).bold())
                        .foregroundStyle(palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(tile.warmth)
                        .font(.title3.bold())
                        .foregroundStyle(palette.tone(warmthTone))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(tile.line)
                        .font(.body)
                        .foregroundStyle(palette.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    MeterBar(title: "CPU", fraction: tile.cpu, limit: nil)
                    MeterBar(title: "RAM", fraction: tile.memory, limit: MachineLimits.memoryAttention)
                    MeterBar(title: "Disk", fraction: tile.disk, limit: MachineLimits.diskAttention)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Pi, \(tile.temperature), \(tile.warmth). \(tile.line)")
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
