import SwiftUI
import StreetPiCore

struct GroupCard: View {
    var group: GroupBrief
    var theme: StreetTheme
    var compact: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: compact ? Rhythm.tight : Rhythm.line) {
                Image(systemName: group.id.symbolName)
                    .font(compact ? .body : .title3)
                    .foregroundStyle(theme.accent)
                    .frame(width: compact ? 22 : 28, alignment: .center)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: compact ? 2 : 4) {
                    Text(group.title)
                        .font(compact ? .subheadline.weight(.semibold) : .headline)
                        .foregroundStyle(theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(group.summary)
                        .font(compact ? .footnote : .subheadline)
                        .foregroundStyle(theme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                ToneMark(tone: group.tone, theme: theme)
                    .padding(.top, compact ? 2 : 4)
            }
            .padding(compact ? Rhythm.tight : Rhythm.line)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(theme.hairline, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(group.title). \(group.summary)")
    }
}

struct GroupDashboard: View {
    var theme: StreetTheme
    var brief: GroupBrief
    var machine: MachineReading?
    var wide: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Rhythm.block) {
                VStack(alignment: .leading, spacing: Rhythm.tight) {
                    Text(brief.title)
                        .font(.system(.largeTitle, design: .rounded))
                        .foregroundStyle(theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        ToneMark(tone: brief.tone, theme: theme)
                        Text(brief.summary)
                            .font(.title3)
                            .foregroundStyle(theme.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if brief.id == .piHealth {
                    meters
                }
                if !brief.rows.isEmpty {
                    VStack(alignment: .leading, spacing: Rhythm.line) {
                        ForEach(brief.rows) { row in
                            ServiceRow(name: row.name, state: row.state, theme: theme)
                            Rectangle()
                                .fill(theme.hairline)
                                .frame(height: 1)
                        }
                    }
                }
            }
            .padding(.horizontal, Rhythm.page)
            .padding(.vertical, Rhythm.block)
            .frame(maxWidth: wide ? 720 : 560)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private var meters: some View {
        VStack(alignment: .leading, spacing: Rhythm.block) {
            if let cpu = machine?.cpuUsedFraction {
                MeterLine(label: "Processor", value: ReadingText.percent(cpu), fraction: cpu, theme: theme)
            }
            if let temperature = machine?.temperatureCelsius {
                MeterLine(
                    label: "Temperature",
                    value: "\(ReadingText.celsius(temperature))  \(ReadingText.warmth(temperature))",
                    fraction: nil,
                    theme: theme
                )
            }
            if let memory = machine?.memoryUsedFraction {
                MeterLine(label: "Memory", value: ReadingText.percent(memory), fraction: memory, theme: theme)
            }
            if let disk = machine?.diskUsedFraction {
                MeterLine(label: "Disk", value: ReadingText.percent(disk), fraction: disk, theme: theme)
            }
            if let uptime = machine?.uptimeSeconds {
                Text(ReadingText.uptime(uptime))
                    .font(.subheadline)
                    .foregroundStyle(theme.tertiary)
            }
        }
    }
}

extension HouseGroup {
    var symbolName: String {
        switch self {
        case .adBlockerAndDNS: "shield"
        case .streaming: "play.rectangle"
        case .smartHome: "lamp.desk"
        case .remoteHelp: "display"
        case .internet: "globe"
        case .piHealth: "cpu"
        case .backups: "externaldrive"
        case .monitors: "list.bullet.rectangle"
        case .address: "network"
        }
    }
}

struct ServiceRow: View {
    var name: String
    var state: String
    var theme: StreetTheme

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline) {
                Text(name)
                    .font(.title3)
                    .foregroundStyle(theme.ink)
                Spacer(minLength: Rhythm.line)
                Text(state)
                    .font(.body)
                    .foregroundStyle(theme.secondary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.title3)
                    .foregroundStyle(theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(state)
                    .font(.body)
                    .foregroundStyle(theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct MeterLine: View {
    var label: String
    var value: String
    var fraction: Double?
    var theme: StreetTheme

    var body: some View {
        VStack(alignment: .leading, spacing: Rhythm.tight) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) {
                    Text(label)
                        .font(.subheadline)
                        .foregroundStyle(theme.secondary)
                        .fixedSize()
                    Spacer(minLength: Rhythm.line)
                    Text(value)
                        .font(.system(.title2, design: .rounded))
                        .foregroundStyle(theme.ink)
                        .fixedSize()
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.subheadline)
                        .foregroundStyle(theme.secondary)
                    Text(value)
                        .font(.system(.title2, design: .rounded))
                        .foregroundStyle(theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if let fraction {
                FractionTrack(fraction: fraction, theme: theme)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label), \(value)")
    }
}
