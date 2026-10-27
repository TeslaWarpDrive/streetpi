import Charts
import StreetPiCore
import SwiftUI

/// The last day for each reading. One card on a phone, two across on the iPad.
struct MetricChartScreen: View {
    var series: [MetricSeries]
    var note: String?
    var theme: StreetTheme
    var wide: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ControlScreen(wide: wide) {
            ControlTitle(title: "Charts", line: intro, theme: theme)
            if series.isEmpty, note != nil {
                Text(LiveReadCopy.tryAgain)
                    .font(.body)
                    .foregroundStyle(theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                AfterglowTileGrid(
                    spacing: AfterglowShape.line,
                    minimumColumnWidth: dynamicTypeSize.isAccessibilitySize ? 10_000 : 300,
                    maximumColumns: 2
                ) {
                    ForEach(series) { item in
                        MetricDayCard(item: item)
                    }
                }
            }
        }
    }

    private var intro: String {
        if let note, series.isEmpty {
            return note
        }
        return "The last day. Nothing here can be changed."
    }
}

/// One reading's day: the latest figure, a plain line, and a solid area chart on hairlines.
private struct MetricDayCard: View {
    var item: MetricSeries

    @Environment(\.afterglowPalette) private var palette

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: AfterglowShape.panel, style: .continuous)
        VStack(alignment: .leading, spacing: AfterglowShape.tight) {
            Text(item.title)
                .font(.headline)
                .foregroundStyle(palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let figure = MetricWords.latest(item) {
                MonoReading(text: figure, emphasize: true)
            }
            Text(MetricWords.plainLine(item))
                .font(.subheadline)
                .foregroundStyle(palette.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if item.points.count > 1 {
                chart
                    .padding(.top, AfterglowShape.tight)
                ViewThatFits(in: .horizontal) {
                    HStack {
                        MonoReading(text: "A day ago")
                        Spacer(minLength: AfterglowShape.line)
                        MonoReading(text: "Now")
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        MonoReading(text: "A day ago")
                        MonoReading(text: "Now")
                    }
                }
            }
        }
        .padding(AfterglowShape.panelPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.panel, in: shape)
        .overlay { shape.strokeBorder(palette.hairline, lineWidth: 1) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(MetricWords.spoken(item))
    }

    private var chart: some View {
        Chart(item.points) { point in
            AreaMark(
                x: .value("Hour", point.hour),
                y: .value("Reading", point.value)
            )
            .foregroundStyle(palette.accent.opacity(0.15))
            .interpolationMethod(.monotone)
            LineMark(
                x: .value("Hour", point.hour),
                y: .value("Reading", point.value)
            )
            .foregroundStyle(palette.accent)
            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            .interpolationMethod(.monotone)
        }
        .chartXScale(domain: 0...23)
        .chartYScale(domain: yDomain)
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(palette.hairline)
            }
        }
        .chartLegend(.hidden)
        .frame(height: 140)
        .accessibilityHidden(true)
    }

    /// Shares run from empty to full. Other readings start at zero and leave headroom.
    private var yDomain: ClosedRange<Double> {
        let peak = item.points.map(\.value).max() ?? 1
        if MetricWords.isShare(item) {
            return 0...max(1, peak)
        }
        return 0...max(peak * 1.15, 0.01)
    }
}

private enum MetricWords {
    static func isShare(_ item: MetricSeries) -> Bool {
        item.id != "temperature"
    }

    static func latest(_ item: MetricSeries) -> String? {
        guard isShare(item), let last = item.points.last else { return nil }
        return ReadingText.percent(last.value)
    }

    static func plainLine(_ item: MetricSeries) -> String {
        switch item.id {
        case "cpu":
            "Share of the processor over the last day."
        case "temperature":
            "How warm the Pi stayed."
        case "memory":
            "Share of memory over the last day."
        case "disk":
            "Share of the disk over the last day."
        default:
            "The last day."
        }
    }

    /// The chart is hidden from VoiceOver, so the card says what the line shows.
    static func spoken(_ item: MetricSeries) -> String {
        let values = item.points.map(\.value)
        guard isShare(item), let last = values.last, let low = values.min(), let high = values.max() else {
            return "\(item.title). \(plainLine(item))"
        }
        return "\(item.title). \(whole(last)) percent now. "
            + "Between \(whole(low)) and \(whole(high)) percent over the last day."
    }

    private static func whole(_ fraction: Double) -> Int {
        Int((fraction * 100).rounded())
    }
}
