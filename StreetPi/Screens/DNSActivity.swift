import SwiftUI
import StreetPiCore

struct DNSStatistics: View {
    var desk: DNSDesk
    var theme: StreetTheme
    var wide: Bool

    var body: some View {
        DeskScroll(wide: wide) {
            Text("Statistics")
                .font(.system(.largeTitle, design: .rounded))
                .foregroundStyle(theme.ink)
                .accessibilityAddTraits(.isHeader)
            if desk.topClients.isEmpty && desk.topDomains.isEmpty && desk.blockedDomains.isEmpty {
                EmptyNote(title: DNSCopy.emptyTopsTitle, detail: DNSCopy.emptyTopsDetail, theme: theme)
            } else {
                countSection("Busiest devices", rows: desk.topClients)
                countSection("Busiest names", rows: desk.topDomains)
                countSection("Most often blocked", rows: desk.blockedDomains)
            }
        }
    }

    private func countSection(_ title: String, rows: [DNSCount]) -> some View {
        VStack(alignment: .leading, spacing: Rhythm.line) {
            Text(title)
                .font(.headline)
                .foregroundStyle(theme.ink)
                .accessibilityAddTraits(.isHeader)
            ForEach(rows) { row in
                DeskCard(theme: theme) {
                    Text(row.name)
                        .font(.headline)
                        .foregroundStyle(theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(row.count)")
                        .font(.subheadline)
                        .foregroundStyle(theme.secondary)
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
    var theme: StreetTheme
    var wide: Bool
    var now: Date
    var onAllow: (String) -> Void

    var body: some View {
        DeskScroll(wide: wide) {
            Text(title)
                .font(.system(.largeTitle, design: .rounded))
                .foregroundStyle(theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if queries.isEmpty {
                EmptyNote(title: emptyTitle, detail: emptyDetail, theme: theme)
            } else {
                ForEach(queries) { query in
                    queryRow(query)
                }
            }
        }
    }

    private func queryRow(_ query: DNSQuery) -> some View {
        DeskCard(theme: theme) {
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
    }
}

struct DNSServices: View {
    var services: [DNSServiceChoice]
    var theme: StreetTheme
    var wide: Bool

    var body: some View {
        DeskScroll(wide: wide) {
            Text("Services")
                .font(.system(.largeTitle, design: .rounded))
                .foregroundStyle(theme.ink)
                .accessibilityAddTraits(.isHeader)
            Text("Kinds of sites the house refuses. This phone does not change them.")
                .font(.body)
                .foregroundStyle(theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if services.isEmpty {
                Text("This phone does not list site categories.")
                    .font(.body)
                    .foregroundStyle(theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(services) { service in
                DeskCard(theme: theme) {
                    Text(service.name)
                        .font(.headline)
                        .foregroundStyle(theme.ink)
                    Text(service.detail)
                        .font(.subheadline)
                        .foregroundStyle(theme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(service.blocked ? "Blocked" : "Allowed")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.ink)
                }
            }
        }
    }
}
