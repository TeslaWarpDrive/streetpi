import SwiftUI
import StreetPiCore

struct DNSPageBody: View {
    var page: DNSPage
    var desk: DNSDesk
    var theme: StreetTheme
    var wide: Bool
    var now: Date
    var onAction: (HouseholdAction) -> Void

    var body: some View {
        switch page {
        case .today:
            DNSToday(desk: desk, theme: theme, wide: wide, onAction: onAction)
        case .statistics:
            DNSStatistics(desk: desk, theme: theme, wide: wide)
        case .queryLog:
            DNSLogScreen(
                title: page.title,
                queries: desk.queries,
                emptyTitle: DNSCopy.emptyQueriesTitle,
                emptyDetail: DNSCopy.emptyQueriesDetail,
                offersAllow: true,
                failureNote: nil,
                theme: theme,
                wide: wide,
                now: now,
                onAllow: { onAction(.allowDomain(named: $0)) }
            )
        case .liveLog:
            DNSLogScreen(
                title: page.title,
                queries: desk.liveQueries,
                emptyTitle: DNSCopy.emptyLiveTitle,
                emptyDetail: DNSCopy.emptyLiveDetail,
                offersAllow: false,
                failureNote: desk.liveReadNote,
                theme: theme,
                wide: wide,
                now: now,
                onAllow: { _ in }
            )
        case .services:
            DNSServices(theme: theme, wide: wide)
        case .clients:
            ReadOnlyRows(
                title: page.title,
                intro: "Devices the house knows.",
                rows: desk.clients,
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
}
