import SwiftUI
import StreetPiCore

struct DNSPageBody: View {
    var page: DNSPage
    var desk: DNSDesk
    var theme: StreetTheme
    var wide: Bool
    var now: Date
    var onAction: (HouseholdAction) -> Void

    @Environment(\.streetPiAway) private var away
    @Environment(\.streetPiReachable) private var reachable

    var body: some View {
        if away, AwayGate.allows(page) == false {
            OnlyAtHomePage(title: page.title, line: page.blurb, theme: theme, wide: wide)
        } else {
            reading
        }
    }

    @ViewBuilder
    private var reading: some View {
        switch page {
        case .today:
            DNSToday(desk: desk, theme: theme, wide: wide, onAction: onAction)
        case .statistics:
            DNSStatistics(desk: desk, theme: theme, wide: wide)
        case .queryLog:
            logScreen(
                page.logHeading(offersAllow: reachable),
                queries: desk.queries,
                onAllow: { onAction(.allowDomain(named: $0)) }
            )
        case .liveLog:
            logScreen(page.logHeading(offersAllow: false), queries: desk.liveQueries, onAllow: { _ in })
        case .services:
            DNSServices(theme: theme, wide: wide)
        case .clients:
            ReadOnlyRows(
                title: page.title,
                intro: "Devices using the Pi for lookups in the last 24 hours.",
                rows: desk.clients,
                notice: desk.clients.isEmpty
                    ? (desk.clientsNote ?? "No devices have made lookups yet. Pull down to refresh.")
                    : nil,
                theme: theme,
                wide: wide
            )
        case .groups:
            ReadOnlyRows(
                title: page.title,
                intro: "Devices that share a rule.",
                rows: desk.groups,
                theme: theme,
                wide: wide
            )
        case .domains:
            DomainScreen(domains: desk.domains, theme: theme, wide: wide, onAction: onAction)
        case .lists:
            ListScreen(lists: desk.lists, theme: theme, wide: wide)
        case .localNames:
            LocalNamesScreen(hosts: desk.hosts, cnames: desk.cnames, theme: theme, wide: wide)
        case .upkeep:
            DNSUpkeep(desk: desk, theme: theme, wide: wide, now: now, onAction: onAction)
        }
    }

    private func logScreen(
        _ heading: DNSLogHeading,
        queries: [DNSQuery],
        onAllow: @escaping (String) -> Void
    ) -> some View {
        let kept = page == .queryLog
        return DNSLogScreen(
            title: page.title,
            line: heading.line,
            queries: queries,
            emptyTitle: kept ? DNSCopy.emptyQueriesTitle : DNSCopy.emptyLiveTitle,
            emptyDetail: kept ? DNSCopy.emptyQueriesDetail : DNSCopy.emptyLiveDetail,
            offersAllow: heading.offersAllow,
            failureNote: kept ? nil : desk.liveReadNote,
            theme: theme,
            wide: wide,
            now: now,
            onAllow: onAllow
        )
    }
}
