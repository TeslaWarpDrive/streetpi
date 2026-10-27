import StreetPiCore
import SwiftUI

/// A chip, the warmth dot, a big temperature, and the three meters.
struct PiBoardCard: View {
    var tile: PiTile
    var onOpen: () -> Void

    @Environment(\.afterglowPalette) private var palette

    var body: some View {
        Button(action: onOpen) {
            BoardPanel {
                VStack(alignment: .leading, spacing: AfterglowShape.tight) {
                    HStack(alignment: .center, spacing: AfterglowShape.tight) {
                        GlanceChip(symbol: "cpu")
                        Spacer(minLength: AfterglowShape.tight)
                        StatusDot(tone: warmthTone)
                        Text(tile.warmth)
                            .font(.subheadline)
                            .foregroundStyle(palette.secondary)
                            .fixedSize(horizontal: true, vertical: true)
                    }
                    .padding(.bottom, 2)
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .firstTextBaseline, spacing: AfterglowShape.tight) {
                            temperature
                            piName
                        }
                        VStack(alignment: .leading, spacing: 0) {
                            temperature
                            piName
                        }
                    }
                    VStack(alignment: .leading, spacing: AfterglowShape.tight) {
                        MeterBar(title: "CPU", fraction: tile.cpu, limit: nil)
                        MeterBar(title: "RAM", fraction: tile.memory, limit: MachineLimits.memoryAttention)
                        MeterBar(title: "Disk", fraction: tile.disk, limit: MachineLimits.diskAttention)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Pi, \(tile.temperature), \(tile.warmth). \(tile.line)")
    }

    private var temperature: some View {
        Text(tile.temperature)
            .font(.system(.largeTitle, design: .rounded).bold().monospacedDigit())
            .foregroundStyle(palette.ink)
            .fixedSize(horizontal: true, vertical: true)
    }

    private var piName: some View {
        Text("The Pi")
            .font(.subheadline)
            .foregroundStyle(palette.secondary)
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
