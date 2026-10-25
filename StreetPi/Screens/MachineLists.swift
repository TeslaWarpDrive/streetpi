import SwiftUI
import StreetPiCore

struct MachineListScreen: View {
    var title: String
    var intro: String
    var rows: [NamedRow]
    var theme: StreetTheme
    var wide: Bool

    var body: some View {
        DeskScroll(wide: wide) {
            Text(title)
                .font(.system(.largeTitle, design: .rounded))
                .foregroundStyle(theme.ink)
                .accessibilityAddTraits(.isHeader)
            Text(intro)
                .font(.body)
                .foregroundStyle(theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(rows) { row in
                VStack(alignment: .leading, spacing: Rhythm.tight) {
                    Text(row.name).font(.headline).foregroundStyle(theme.ink)
                    Text(row.detail).font(.subheadline).foregroundStyle(theme.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Rhythm.line)
                .background(theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        }
    }
}

struct AlertsScreen: View {
    var alerts: [HouseAlert]
    var theme: StreetTheme
    var wide: Bool

    var body: some View {
        DeskScroll(wide: wide) {
            Text("Alerts")
                .font(.system(.largeTitle, design: .rounded))
                .foregroundStyle(theme.ink)
                .accessibilityAddTraits(.isHeader)
            if alerts.isEmpty {
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
