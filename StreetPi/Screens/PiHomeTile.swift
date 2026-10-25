import StreetPiCore
import SwiftUI

/// Temperature, Cool/Warm/Hot, and the three bars.
struct PiHomeTile: View {
    var reading: HomePiReading
    var action: () -> Void

    @Environment(\.afterglowPalette) private var palette

    var body: some View {
        Button(action: action) {
            AfterglowPlate(
                cornerRadius: AfterglowShape.panel,
                interactive: true,
                contentPadding: AfterglowShape.tilePadding
            ) {
                VStack(alignment: .leading, spacing: AfterglowShape.line) {
                    Text("Pi")
                        .font(.subheadline)
                        .foregroundStyle(palette.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(alignment: .firstTextBaseline, spacing: AfterglowShape.line) {
                        Text(reading.temperature)
                            .font(.largeTitle.bold())
                            .foregroundStyle(palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(reading.warmth)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(palette.tone(reading.warmthTone))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    VStack(alignment: .leading, spacing: AfterglowShape.line) {
                        ForEach(reading.meters) { meter in
                            HomeMeterBar(meter: meter)
                        }
                    }
                    Text(reading.line)
                        .font(.body)
                        .foregroundStyle(palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(reading.spoken)
    }
}

struct HomeMeterBar: View {
    var meter: HomeMeter

    @Environment(\.afterglowPalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: AfterglowShape.line) {
                Text(meter.title)
                    .font(.subheadline)
                    .foregroundStyle(palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: AfterglowShape.line)
                Text(meter.value)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(palette.ink)
                    .fixedSize(horizontal: true, vertical: true)
            }
            GeometryReader { proxy in
                let width = max(4, proxy.size.width * meter.fraction)
                ZStack(alignment: .leading) {
                    Capsule().fill(palette.hairline)
                    Capsule().fill(palette.accent).frame(width: width)
                }
            }
            .frame(height: 6)
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }
}
