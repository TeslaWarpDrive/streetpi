import StreetPiCore
import SwiftUI

/// Stopped each hour, last 24 hours. A dim bar is every lookup in the hour; the lavender part is what was stopped.
struct HourBars: View {
    var samples: [DayChartSample]
    var stopped: Int

    @Environment(\.afterglowPalette) private var palette
    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 110

    var body: some View {
        VStack(alignment: .leading, spacing: AfterglowShape.line) {
            Text("Stopped each hour, last 24 hours")
                .font(.headline)
                .foregroundStyle(palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: AfterglowShape.tight) {
                bars
                axis
                legend
            }
            .padding(AfterglowShape.line)
            .background(palette.panel, in: RoundedRectangle(cornerRadius: AfterglowShape.panel, style: .continuous))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
    }

    private var bars: some View {
        let peak = max(1, samples.map { $0.allowed + $0.blocked }.max() ?? 1)
        return HStack(alignment: .bottom, spacing: 3) {
            ForEach(samples) { sample in
                let total = CGFloat(sample.allowed + sample.blocked) / CGFloat(peak) * height
                let part = CGFloat(sample.blocked) / CGFloat(peak) * height
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(palette.panelRaised)
                        .frame(height: max(total, 3))
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(palette.accent)
                        .frame(height: max(part, sample.blocked == 0 ? 0 : 3))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: height, alignment: .bottom)
    }

    private var axis: some View {
        ViewThatFits(in: .horizontal) {
            axisRow(axisLabels)
            axisRow([axisLabels.first ?? "", "Now"])
        }
    }

    private func axisRow(_ labels: [String]) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                Text(label)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(palette.tertiary)
                    .fixedSize()
                if index < labels.count - 1 {
                    Spacer(minLength: 2)
                }
            }
        }
    }

    private var legend: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: AfterglowShape.line) {
                swatch(palette.accent, "Stopped")
                swatch(palette.panelRaised, "All lookups")
            }
            VStack(alignment: .leading, spacing: AfterglowShape.tight) {
                swatch(palette.accent, "Stopped")
                swatch(palette.panelRaised, "All lookups")
            }
        }
    }

    private func swatch(_ color: Color, _ word: String) -> some View {
        HStack(spacing: AfterglowShape.tight) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(color)
                .frame(width: 10, height: 10)
            Text(word)
                .font(.caption)
                .foregroundStyle(palette.secondary)
        }
    }

    /// Five marks: the first hour, every sixth hour, then "Now".
    private var axisLabels: [String] {
        guard samples.isEmpty == false else { return [] }
        var labels: [String] = []
        for index in stride(from: 0, to: samples.count - 1, by: 6) {
            labels.append(Self.clock(samples[index].hour))
        }
        labels.append("Now")
        return labels
    }

    private var spoken: String {
        let busiest = samples.max { $0.blocked < $1.blocked }
        guard let busiest, busiest.blocked > 0 else {
            return "Stopped each hour, last 24 hours. \(stopped.formatted()) stopped."
        }
        return "Stopped each hour, last 24 hours. \(stopped.formatted()) stopped. "
            + "The busiest hour was \(Self.clock(busiest.hour)), with \(busiest.blocked.formatted()) stopped."
    }

    static func clock(_ hour: Int) -> String {
        let normal = ((hour % 24) + 24) % 24
        let twelve = normal % 12 == 0 ? 12 : normal % 12
        return "\(twelve) \(normal < 12 ? "AM" : "PM")"
    }
}
