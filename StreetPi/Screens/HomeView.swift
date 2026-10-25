import SwiftUI
import StreetPiCore

struct HomeView: View {
    var theme: StreetTheme
    var snapshot: HouseholdSnapshot?
    var status: PlainEnglishStatus
    var lines: [String]
    var groups: [GroupBrief]
    var wide: Bool
    var piNotice: String?
    var showsBriefing: Bool = true
    var onGroup: (HouseGroup) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Rhythm.block) {
                if showsBriefing {
                    statusCard
                }
                readings
                if !groups.isEmpty {
                    groupGrid
                }
            }
            .padding(.horizontal, Rhythm.page)
            .padding(.vertical, showsBriefing ? Rhythm.block : Rhythm.line)
            .frame(maxWidth: wide ? 880 : 560)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .scrollContentBackground(.hidden)
    }

    private var statusCard: some View {
        StatusCard(theme: theme) {
            VStack(alignment: .leading, spacing: Rhythm.line) {
                StatusLinkRow(text: status.linkLine, tone: status.tone, theme: theme, pulsing: status.tone == .calm)
                Text(status.headline)
                    .font(.system(.title, design: .rounded, weight: .semibold))
                    .foregroundStyle(theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.isHeader)
                if let detail = status.detail {
                    Text(detail)
                        .font(.body)
                        .foregroundStyle(theme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !lines.isEmpty {
                    VStack(alignment: .leading, spacing: Rhythm.tight) {
                        ForEach(lines, id: \.self) { line in
                            Text(line)
                                .font(.body)
                                .foregroundStyle(theme.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.top, Rhythm.tight)
                }
            }
        }
    }

    private var readings: some View {
        VStack(alignment: .leading, spacing: Rhythm.block) {
            if snapshot?.machine == nil, let piNotice {
                Text(piNotice)
                    .font(.body)
                    .foregroundStyle(theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let cpu = snapshot?.machine?.cpuUsedFraction {
                MeterRow(label: "Processor", value: ReadingText.percent(cpu), fraction: cpu, theme: theme)
            }
            if let temperature = snapshot?.machine?.temperatureCelsius {
                MeterRow(
                    label: "Temperature",
                    value: "\(ReadingText.celsius(temperature))  \(ReadingText.warmth(temperature))",
                    fraction: nil,
                    theme: theme
                )
            }
            if let memory = snapshot?.machine?.memoryUsedFraction {
                MeterRow(label: "Memory", value: ReadingText.percent(memory), fraction: memory, theme: theme)
            }
            if let disk = snapshot?.machine?.diskUsedFraction {
                MeterRow(label: "Disk", value: ReadingText.percent(disk), fraction: disk, theme: theme)
            }
            if let uptime = snapshot?.machine?.uptimeSeconds {
                MeterRow(label: "Uptime", value: ReadingText.uptime(uptime), fraction: nil, theme: theme)
            }
        }
    }

    private var groupGrid: some View {
        let twoColumns = !dynamicTypeSize.isAccessibilitySize && (wide || showsBriefing == false)
        let columns = twoColumns
            ? [GridItem(.flexible(), spacing: Rhythm.line), GridItem(.flexible(), spacing: Rhythm.line)]
            : [GridItem(.flexible())]
        let compact = showsBriefing == false
        return LazyVGrid(columns: columns, alignment: .leading, spacing: compact ? Rhythm.tight : Rhythm.line) {
            ForEach(groups) { group in
                GroupCard(group: group, theme: theme, compact: compact) {
                    onGroup(group.id)
                }
            }
        }
    }
}

private struct StatusLinkRow: View {
    var text: String
    var tone: PlainEnglishStatus.Tone
    var theme: StreetTheme
    var pulsing: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.streetPiStill) private var still

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Rhythm.line) {
            Image(systemName: "house.fill")
                .font(.title2)
                .foregroundStyle(theme.accent)
                .symbolEffect(.pulse, options: .repeating, isActive: pulsing && !reduceMotion && !still)
                .accessibilityHidden(true)
                .fixedSize()
                .layoutPriority(1)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            ToneMark(tone: tone, theme: theme)
                .fixedSize()
                .layoutPriority(1)
        }
    }
}

private struct StatusCard<Content: View>: View {
    var theme: StreetTheme
    @Environment(\.streetPiStill) private var still
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(Rhythm.block)
            .background { plate }
    }

    /// Glass does not rasterize in the snapshot harness. The words sit on a solid plate.
    /// On a live iOS 26 phone, glass is a layer behind that plate.
    @ViewBuilder
    private var plate: some View {
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)
        if #available(iOS 26, *), !still {
            shape
                .fill(theme.surface)
                .glassEffect(.regular.tint(theme.accent.opacity(0.22)), in: .rect(cornerRadius: 28))
        } else if !still {
            shape.fill(.ultraThinMaterial)
        } else {
            shape
                .fill(theme.surface)
                .overlay {
                    shape.stroke(theme.hairline, lineWidth: 1)
                }
        }
    }
}

private struct MeterRow: View {
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
                Text(state)
                    .font(.body)
                    .foregroundStyle(theme.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
