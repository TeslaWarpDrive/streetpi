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
        DeskScroll(wide: wide) {
            VStack(alignment: .leading, spacing: Rhythm.tight) {
                Text("The Pi")
                    .font(.system(.largeTitle, design: .rounded))
                    .foregroundStyle(theme.ink)
                    .accessibilityAddTraits(.isHeader)
                Text(placeLine)
                    .font(.title3)
                    .foregroundStyle(theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if machine?.hasSignal != true, let piNotice {
                    Text(piNotice)
                        .font(.body)
                        .foregroundStyle(theme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if let cpu = machine?.cpuUsedFraction {
                meter("Processor", ReadingText.percent(cpu), cpu)
            }
            if let temperature = machine?.temperatureCelsius {
                meter("Temperature", "\(ReadingText.celsius(temperature))  \(ReadingText.warmth(temperature))", nil)
            }
            if let memory = machine?.memoryUsedFraction {
                meter("Memory", ReadingText.percent(memory), memory)
            }
            if let disk = machine?.diskUsedFraction {
                meter("Disk", ReadingText.percent(disk), disk)
            }
            if let uptime = machine?.uptimeSeconds {
                meter("Uptime", ReadingText.uptime(uptime), nil)
            }
            if showsDestinations {
                ForEach(MachinePage.allCases.filter { $0 != .dashboard }) { page in
                    DeskLink(title: page.title, blurb: page.blurb, symbol: page.symbolName, theme: theme) {
                        onPage(page)
                    }
                }
            }
        }
    }

    private var placeLine: String {
        if desk.host.isEmpty { return desk.modelName }
        if desk.modelName.isEmpty { return desk.host }
        return "\(desk.modelName) at \(desk.host)"
    }

    private func meter(_ label: String, _ value: String, _ fraction: Double?) -> some View {
        VStack(alignment: .leading, spacing: Rhythm.tight) {
            ViewThatFits(in: .horizontal) {
                HStack {
                    Text(label).font(.subheadline).foregroundStyle(theme.secondary).fixedSize()
                    Spacer(minLength: Rhythm.line)
                    Text(value)
                        .font(.system(.title3, design: .rounded))
                        .foregroundStyle(theme.ink)
                        .fixedSize()
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(label).font(.subheadline).foregroundStyle(theme.secondary)
                    Text(value)
                        .font(.system(.title3, design: .rounded))
                        .foregroundStyle(theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if let fraction {
                FractionTrack(fraction: fraction, theme: theme)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct MetricChartScreen: View {
    var series: [MetricSeries]
    var theme: StreetTheme
    var wide: Bool

    var body: some View {
        DeskScroll(wide: wide) {
            Text("Charts")
                .font(.system(.largeTitle, design: .rounded))
                .foregroundStyle(theme.ink)
                .accessibilityAddTraits(.isHeader)
            Text("The last day, from the sample. Nothing here can be changed.")
                .font(.body)
                .foregroundStyle(theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(series) { item in
                chart(item)
            }
        }
    }

    private func chart(_ item: MetricSeries) -> some View {
        VStack(alignment: .leading, spacing: Rhythm.line) {
            Text(item.title)
                .font(.headline)
                .foregroundStyle(theme.ink)
                .accessibilityAddTraits(.isHeader)
            bars(item.points)
            Text(item.caption)
                .font(.footnote)
                .foregroundStyle(theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.title). \(item.caption)")
    }

    private func bars(_ points: [MetricPoint]) -> some View {
        let peak = max(0.01, points.map(\.value).max() ?? 1)
        return HStack(alignment: .bottom, spacing: 3) {
            ForEach(points) { point in
                Rectangle()
                    .fill(theme.accent)
                    .frame(height: max(4, CGFloat(point.value / peak) * 120))
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 120, alignment: .bottom)
    }
}
