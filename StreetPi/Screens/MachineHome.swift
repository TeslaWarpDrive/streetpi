import SwiftUI
import StreetPiCore

struct MachineHome: View {
    var desk: MachineDesk
    var machine: MachineReading?
    var theme: StreetTheme
    var wide: Bool
    var showsDestinations: Bool = true
    var piNotice: String?
    var onPage: (MachinePage) -> Void

    var body: some View {
        ControlScreen(wide: wide) {
            ControlTitle(title: "The Pi", line: placeLine, theme: theme)
            if machine?.hasSignal != true, let piNotice {
                Text(piNotice)
                    .font(.body)
                    .foregroundStyle(theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ControlGrid {
                readings
            }
            if showsDestinations {
                ControlSection(title: "More", theme: theme)
                ControlGrid {
                    ForEach(MachinePage.allCases.filter { $0 != .dashboard }) { page in
                        LinkTile(
                            title: page.title,
                            line: page.blurb,
                            symbol: page.symbolName,
                            theme: theme,
                            finalLineLayout: page == .containers ? "page-end" : nil,
                            action: { onPage(page) }
                        )
                    }
                }
            }
        }
    }

    private var placeLine: String {
        let model = desk.modelName
        let host = displayedHost
        if model.isEmpty { return host.isEmpty ? "The Pi" : host }
        if host.isEmpty { return model }
        return "\(model) at \(host)"
    }

    /// The fixture host is not a machine the house can open.
    private var displayedHost: String {
        let host = desk.host.trimmingCharacters(in: .whitespacesAndNewlines)
        if host.isEmpty || host == "fixture.local" { return "" }
        return host
    }

    @ViewBuilder
    private var readings: some View {
        if let cpu = machine?.cpuUsedFraction {
            NumberTile(
                label: "Processor",
                number: ReadingText.percent(cpu),
                line: "In use right now.",
                theme: theme
            )
        }
        if let temperature = machine?.temperatureCelsius {
            NumberTile(
                label: "Temperature",
                number: ReadingText.celsius(temperature),
                line: ReadingText.warmth(temperature),
                theme: theme
            )
        }
        if let memory = machine?.memoryUsedFraction {
            NumberTile(
                label: "Memory",
                number: ReadingText.percent(memory),
                line: "In use right now.",
                theme: theme
            )
        }
        if let disk = machine?.diskUsedFraction {
            NumberTile(
                label: "Disk",
                number: ReadingText.percent(disk),
                line: diskLine(disk),
                theme: theme
            )
        }
        if let uptime = machine?.uptimeSeconds {
            NumberTile(
                label: "Uptime",
                number: uptimeNumber(uptime),
                line: uptimeLine(uptime),
                theme: theme
            )
        }
    }

    private func diskLine(_ fraction: Double) -> String {
        fraction >= MachineLimits.diskAttention ? "Almost full." : "Space in use."
    }

    private func uptimeNumber(_ seconds: TimeInterval) -> String {
        if seconds < 3_600 {
            return "<1"
        }
        let hours = Int(seconds / 3_600)
        if hours < 48 {
            return "\(hours)"
        }
        return "\(max(1, Int(seconds / 86_400)))"
    }

    private func uptimeLine(_ seconds: TimeInterval) -> String {
        if seconds < 3_600 {
            return "Hour since the Pi started."
        }
        let hours = Int(seconds / 3_600)
        if hours < 48 {
            return hours == 1 ? "Hour since the Pi started." : "Hours since the Pi started."
        }
        let days = max(1, Int(seconds / 86_400))
        return days == 1 ? "Day since the Pi started." : "Days since the Pi started."
    }
}

struct MetricChartScreen: View {
    var series: [MetricSeries]
    var note: String?
    var theme: StreetTheme
    var wide: Bool

    var body: some View {
        ControlScreen(wide: wide) {
            ControlTitle(title: "Charts", line: intro, theme: theme)
            if series.isEmpty, note != nil {
                Text(LiveReadCopy.tryAgain)
                    .font(.body)
                    .foregroundStyle(theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(series) { item in
                    chart(item)
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

    private func chart(_ item: MetricSeries) -> some View {
        VStack(alignment: .leading, spacing: Rhythm.line) {
            Text(item.title)
                .font(.headline)
                .foregroundStyle(theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if let figure = latestFigure(item) {
                Text(figure)
                    .font(.system(.largeTitle, design: .rounded))
                    .foregroundStyle(theme.accent)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(plainLine(item))
                .font(.subheadline)
                .foregroundStyle(theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
            bars(item.points)
        }
        .controlPlate(theme: theme)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken(item))
    }

    private func spoken(_ item: MetricSeries) -> String {
        if let figure = latestFigure(item) {
            return "\(item.title). \(figure). \(plainLine(item))"
        }
        return "\(item.title). \(plainLine(item))"
    }

    private func latestFigure(_ item: MetricSeries) -> String? {
        guard item.id != "temperature", let last = item.points.last else { return nil }
        return ReadingText.percent(last.value)
    }

    private func plainLine(_ item: MetricSeries) -> String {
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

    private func bars(_ points: [MetricPoint]) -> some View {
        let peak = max(0.01, points.map(\.value).max() ?? 1)
        return HStack(alignment: .bottom, spacing: 3) {
            ForEach(points) { point in
                Rectangle()
                    .fill(theme.accent)
                    .frame(height: max(4, CGFloat(point.value / peak) * 72))
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 72, alignment: .bottom)
        .accessibilityHidden(true)
    }
}
