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

/// One template for every room: icon header, a line of status, member rows with chips,
/// then what it all means in plain words.
struct GroupDashboard: View {
    var theme: StreetTheme
    var brief: GroupBrief
    var machine: MachineReading?
    var wide: Bool

    @Environment(\.afterglowPalette) private var palette

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AfterglowShape.block) {
                header
                if brief.id == .piHealth, let machine {
                    MachineRings(machine: machine, onOpen: nil)
                }
                if !brief.rows.isEmpty {
                    StatusList(lines: lines, mark: .chip)
                } else if brief.id != .piHealth || machine == nil {
                    Text("No checks to show yet. Pull down to refresh. " +
                         "If this keeps happening, check the status page in Settings.")
                        .font(.body)
                        .foregroundStyle(palette.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                meaning
            }
            .padding(.horizontal, AfterglowShape.page)
            .padding(.vertical, AfterglowShape.block)
            .frame(maxWidth: wide ? 720 : 560)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .background(palette.ground.ignoresSafeArea())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AfterglowShape.line) {
            IconChip(systemImage: brief.id.symbolName)
            Text(brief.title)
                .font(AfterglowType.title)
                .foregroundStyle(palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            HStack(alignment: .firstTextBaseline, spacing: AfterglowShape.tight) {
                StatusDot(tone: brief.tone)
                Text(brief.summary)
                    .font(.body)
                    .foregroundStyle(palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var lines: [StatusLine] {
        brief.rows.map { row in
            StatusLine(id: row.id, name: row.name, word: row.state, tone: row.tone ?? brief.tone)
        }
    }

    private var meaning: some View {
        VStack(alignment: .leading, spacing: AfterglowShape.tight) {
            KickerLabel(text: "What this means")
            Text(HouseGuide.meaning(for: brief.id))
                .font(.body)
                .foregroundStyle(palette.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, AfterglowShape.tight)
    }
}

extension HouseGroup {
    var symbolName: String {
        switch self {
        case .adBlockerAndDNS: "shield.lefthalf.filled"
        case .streaming: "play.tv"
        case .smartHome: "house"
        case .remoteHelp: "display"
        case .internet: "globe"
        case .piHealth: "cpu"
        case .backups: "externaldrive.badge.timemachine"
        case .monitors: "list.bullet.rectangle"
        case .address: "network"
        }
    }
}
