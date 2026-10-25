import SwiftUI
import StreetPiCore

struct MachineListScreen: View {
    var title: String
    var intro: String
    var rows: [NamedRow]
    var note: String?
    var theme: StreetTheme
    var wide: Bool

    var body: some View {
        ControlScreen(wide: wide) {
            ControlTitle(title: title, line: intro, theme: theme)
            if let note {
                PlainTile(title: note, line: LiveReadCopy.tryAgain, theme: theme)
            }
            ControlGrid {
                ForEach(rows) { row in
                    PlainTile(title: row.name, line: row.detail, theme: theme)
                }
            }
        }
    }
}

struct AlertsScreen: View {
    var alerts: [HouseAlert]
    var note: String?
    var theme: StreetTheme
    var wide: Bool

    var body: some View {
        DeskScroll(wide: wide) {
            Text("Alerts")
                .font(.system(.largeTitle, design: .rounded))
                .foregroundStyle(theme.ink)
                .accessibilityAddTraits(.isHeader)
            if let note, alerts.isEmpty {
                Text(note)
                    .font(.body)
                    .foregroundStyle(theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(LiveReadCopy.tryAgain)
                    .font(.subheadline)
                    .foregroundStyle(theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else if alerts.isEmpty {
                EmptyNote(
                    title: "No alarms are raised.",
                    detail: "These stay in the app. Raspberry Pi Stats does not send push notifications.",
                    theme: theme
                )
            } else {
                Text("These stay in the app. Raspberry Pi Stats does not send push notifications.")
                    .font(.body)
                    .foregroundStyle(theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(alerts) { alert in
                    HStack(alignment: .top, spacing: Rhythm.line) {
                        ToneMark(tone: alert.tone, theme: theme)
                        Text(alert.sentence)
                            .font(.body)
                            .foregroundStyle(theme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}
