import StreetPiCore
import SwiftUI

/// Services and containers. Each row is a name with its status beside it, never color alone.
struct MachineListScreen: View {
    var title: String
    var intro: String
    var rows: [NamedRow]
    var note: String?
    var mark: StatusMark
    var groupsServices = false
    var theme: StreetTheme
    var wide: Bool

    var body: some View {
        ControlScreen(wide: wide) {
            ControlTitle(title: title, line: intro, theme: theme)
            if let note {
                PlainTile(title: note, line: LiveReadCopy.tryAgain, theme: theme)
            }
            if !rows.isEmpty {
                if groupsServices {
                    ServiceGroups(rows: rows)
                } else {
                    StatusList(lines: lines, mark: mark)
                }
            }
        }
    }

    private var lines: [StatusLine] {
        rows.map { row in
            StatusLine(
                id: row.id,
                name: row.name,
                word: row.detail,
                tone: StatusLine.tone(forWord: row.detail)
            )
        }
    }
}

/// A timeline of raised alarms. The time shows only when the source gave one.
struct AlertsScreen: View {
    var alerts: [HouseAlert]
    var note: String?
    var theme: StreetTheme
    var wide: Bool

    @Environment(\.afterglowPalette) private var palette

    var body: some View {
        DeskScroll(wide: wide) {
            Text("Alerts")
                .font(AfterglowType.display)
                .foregroundStyle(palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if let note, alerts.isEmpty {
                Text(note)
                    .font(.body)
                    .foregroundStyle(palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(LiveReadCopy.tryAgain)
                    .font(.subheadline)
                    .foregroundStyle(palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else if alerts.isEmpty {
                AlertsQuiet()
            } else {
                Text(Self.stayLine)
                    .font(.body)
                    .foregroundStyle(palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(alerts.enumerated()), id: \.element.id) { index, alert in
                        AlertTimelineRow(alert: alert, isLast: index == alerts.count - 1)
                    }
                }
            }
        }
    }

    static let stayLine = "These stay in the app. Raspberry Pi Stats does not send push notifications."
}

private struct AlertTimelineRow: View {
    var alert: HouseAlert
    var isLast: Bool

    @Environment(\.afterglowPalette) private var palette

    var body: some View {
        HStack(alignment: .top, spacing: AfterglowShape.line) {
            VStack(spacing: AfterglowShape.tight) {
                Image(systemName: AfterglowSymbol.status(alert.tone))
                    .font(.title3)
                    .foregroundStyle(palette.tone(alert.tone))
                    .accessibilityHidden(true)
                if !isLast {
                    Rectangle()
                        .fill(palette.hairline)
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                        .accessibilityHidden(true)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                if let raisedAt = alert.raisedAt {
                    Text(raisedAt, format: .dateTime.weekday(.abbreviated).hour().minute())
                        .font(AfterglowType.metadata)
                        .foregroundStyle(palette.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(alert.sentence)
                    .font(.body)
                    .foregroundStyle(palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, isLast ? 0 : AfterglowShape.block)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // Lets the rail run the full height of the row.
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }
}

/// "Nothing needs you right now." over a dim aura that never moves.
private struct AlertsQuiet: View {
    @Environment(\.afterglowPalette) private var palette
    @Environment(\.afterglowGate) private var gate

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: AfterglowShape.panel, style: .continuous)
        VStack(alignment: .leading, spacing: AfterglowShape.line) {
            Label {
                Text("Nothing needs you right now.")
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: AfterglowSymbol.status(.calm))
                    .foregroundStyle(palette.calm)
                    .accessibilityHidden(true)
            }
            .font(AfterglowType.title)
            .foregroundStyle(palette.ink)
            .accessibilityAddTraits(.isHeader)
            Text(AlertsScreen.stayLine)
                .font(.body)
                .foregroundStyle(palette.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(AfterglowShape.panelPadding)
        .padding(.top, 96)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            AuraView(tone: .calm)
                .environment(\.afterglowGate, stillGate)
                .opacity(0.35)
                .accessibilityHidden(true)
        }
        .background(palette.ground)
        .clipShape(shape)
        .overlay { shape.strokeBorder(palette.hairline, lineWidth: 1) }
    }

    /// Always the fixed wash: no mesh, no timeline, whatever Reduce Motion says.
    private var stillGate: AfterglowMotionGate {
        AfterglowMotionGate(reduceMotion: true, still: gate.still, reduceTransparency: gate.reduceTransparency)
    }
}
