import StreetPiCore
import SwiftUI

/// A labeled bar. The percent sits beside the name, so the color is not the only status.
struct MeterBar: View {
    var title: String
    var fraction: Double?
    var limit: Double?

    @Environment(\.afterglowPalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: AfterglowShape.line) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(palette.secondary)
                Spacer(minLength: AfterglowShape.line)
                Text(reading)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(palette.ink)
            }
            Capsule()
                .fill(palette.hairline)
                .frame(height: 8)
                .overlay(alignment: .leading) {
                    GeometryReader { proxy in
                        Capsule()
                            .fill(barColor)
                            .frame(width: proxy.size.width * clamped)
                    }
                }
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }

    private var reading: String {
        guard let fraction else { return "—" }
        return ReadingText.percent(fraction)
    }

    private var clamped: Double {
        min(max(fraction ?? 0, 0), 1)
    }

    private var barColor: Color {
        if let fraction, let limit, fraction >= limit {
            return palette.attention
        }
        return palette.accent
    }
}
