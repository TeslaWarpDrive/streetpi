import SwiftUI
import StreetPiCore

struct MachinePageBody: View {
    var page: MachinePage
    var desk: MachineDesk
    var machine: MachineReading?
    var theme: StreetTheme
    var wide: Bool
    var showsDestinations: Bool = true
    var piNotice: String?
    var onPage: (MachinePage) -> Void

    @Environment(\.streetPiAway) private var away

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
        case .dashboard:
            MachineHome(
                desk: desk,
                machine: machine,
                theme: theme,
                wide: wide,
                showsDestinations: showsDestinations,
                piNotice: piNotice,
                onPage: onPage
            )
        case .chart:
            MetricChartScreen(series: desk.series, note: desk.chartNote, theme: theme, wide: wide)
        case .services:
            MachineListScreen(
                title: page.title,
                intro: "Up or down comes from the status page. Nothing here can be changed.",
                rows: desk.services,
                note: desk.services.isEmpty ? "No checks to show yet." : nil,
                mark: .dot,
                groupsServices: true,
                theme: theme,
                wide: wide
            )
        case .containers:
            MachineListScreen(
                title: page.title,
                intro: "These are the boxed jobs on the charts. Nothing here can be changed.",
                rows: desk.containers,
                note: desk.containerNote,
                mark: .chip,
                theme: theme,
                wide: wide
            )
        }
    }
}
