import SwiftUI
import StreetPiCore

struct DNSStatistics: View {
    var desk: DNSDesk
    var theme: StreetTheme
    var wide: Bool

    var body: some View {
        ControlScreen(wide: wide) {
            ControlTitle(
                title: "Statistics",
                line: "The busiest names and devices.",
                theme: theme
            )
            if desk.topClients.isEmpty && desk.topDomains.isEmpty && desk.blockedDomains.isEmpty {
                PlainTile(
                    title: DNSCopy.emptyTopsTitle,
                    line: DNSCopy.emptyTopsDetail,
                    theme: theme
                )
            } else {
                countSection("Busiest devices", rows: desk.topClients, line: "Lookups from this device.")
                countSection("Busiest names", rows: desk.topDomains, line: "Times this name was looked up.")
                countSection("Most often blocked", rows: desk.blockedDomains, line: "Times this name was turned away.")
            }
        }
    }

    @ViewBuilder
    private func countSection(_ title: String, rows: [DNSCount], line: String) -> some View {
        if rows.isEmpty == false {
            ControlSection(title: title, theme: theme)
            ControlGrid {
                ForEach(rows) { row in
                    NumberTile(
                        label: row.name,
                        number: row.count.formatted(),
                        line: line,
                        theme: theme
                    )
                }
            }
        }
    }
}

struct DNSLogScreen: View {
    var title: String
    var queries: [DNSQuery]
    var emptyTitle: String
    var emptyDetail: String
    var offersAllow: Bool
    var failureNote: String?
    var theme: StreetTheme
    var wide: Bool
    var now: Date
    var onAllow: (String) -> Void

    var body: some View {
        ControlScreen(wide: wide) {
            ControlTitle(title: title, line: logLine, theme: theme)
            if queries.isEmpty {
                if let failureNote {
                    PlainTile(title: failureNote, line: LiveReadCopy.tryAgain, theme: theme)
                } else {
                    PlainTile(title: emptyTitle, line: emptyDetail, theme: theme)
                }
            } else {
                ForEach(queries) { query in
                    queryRow(query)
                }
            }
        }
    }

    private var logLine: String {
        offersAllow ? "Lookups the Pi has kept." : "Lookups as they happen."
    }

    private func queryRow(_ query: DNSQuery) -> some View {
        VStack(alignment: .leading, spacing: Rhythm.line) {
            Text(query.domain)
                .font(.headline)
                .foregroundStyle(theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text("\(query.client) · \(AgePhrase.english(from: query.at, to: now)) · \(query.outcome.word)")
                .font(.subheadline)
                .foregroundStyle(theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if offersAllow {
                Button("Allow") {
                    onAllow(query.domain)
                }
                .font(.body.weight(.semibold))
                .foregroundStyle(theme.accent)
                .frame(minHeight: 44, alignment: .leading)
                .accessibilityLabel("Allow \(query.domain)")
            }
        }
        .controlPlate(theme: theme)
        .accessibilityElement(children: .contain)
    }
}

struct DNSServices: View {
    var theme: StreetTheme
    var wide: Bool

    var body: some View {
        ControlScreen(wide: wide) {
            ControlTitle(
                title: "Ad blocker",
                line: "Ads are blocked for the whole house.",
                theme: theme
            )
        }
    }
}
