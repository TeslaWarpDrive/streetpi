import StreetPiCore
import SwiftUI

/// A chip, the warmth dot, a big temperature, and the three meters.
struct PiBoardCard: View {
    var tile: PiTile
    var onOpen: () -> Void

    @Environment(\.afterglowPalette) private var palette

    var body: some View {
        Button(action: onOpen) {
            BoardPanel(inset: 4) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .center, spacing: 6) {
                        Image(systemName: "cpu")
                            .font(.footnote)
                            .foregroundStyle(palette.accent)
                            .frame(width: 28, height: 28)
                            .background(palette.accent.opacity(0.16), in: Circle())
                            .accessibilityHidden(true)
                        Spacer(minLength: 4)
                        StatusDot(tone: warmthTone)
                        Text(tile.warmth)
                            .font(.caption2)
                            .foregroundStyle(palette.secondary)
                            .fixedSize(horizontal: true, vertical: true)
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(tile.temperature)
                            .font(.system(.title2, design: .rounded).bold())
                            .foregroundStyle(palette.ink)
                            .fixedSize(horizontal: true, vertical: true)
                        Text("The Pi")
                            .font(.caption)
                            .foregroundStyle(palette.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
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
