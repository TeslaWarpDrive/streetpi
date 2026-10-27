import StreetPiCore
import SwiftUI

/// A labeled bar. The percent sits with the name, so the color is not the only status.
struct MeterBar: View {
    var title: String
    var fraction: Double?
    var limit: Double?

    @Environment(\.afterglowPalette) private var palette

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 4) {
                name
                track
                readingText
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    name
                    Spacer(minLength: 4)
                    readingText
                }
                track
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var name: some View {
        Text(title)
            .font(.subheadline)
            .foregroundStyle(palette.secondary)
            .fixedSize(horizontal: true, vertical: true)
    }

    private var readingText: some View {
        Text(reading)
            .font(.subheadline.monospacedDigit())
            .foregroundStyle(palette.ink)
            .fixedSize(horizontal: true, vertical: true)
    }

    private var track: some View {
        Capsule()
            .fill(palette.hairline)
            .frame(height: 4)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(barColor)
                        .frame(width: proxy.size.width * clamped)
                }
            }
            .accessibilityHidden(true)
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
