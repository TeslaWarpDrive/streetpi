import SwiftUI
import StreetPiCore

struct MachinePageBody: View {
    var page: MachinePage
    var desk: MachineDesk
    var machine: MachineReading?
    var theme: StreetTheme
    var wide: Bool
    var showsDestinations: Bool = true
    var onPage: (MachinePage) -> Void

    var body: some View {
        switch page {
        case .dashboard:
            MachineHome(
                desk: desk,
                machine: machine,
                theme: theme,
                wide: wide,
                showsDestinations: showsDestinations,
                onPage: onPage
            )
        case .chart:
            MetricChartScreen(series: desk.series, note: desk.chartNote, theme: theme, wide: wide)
        case .services:
            MachineListScreen(
                title: page.title,
                intro: "Up or down comes from the status page. Nothing here can be changed.",
                rows: desk.services,
                theme: theme,
                wide: wide
            )
        case .containers:
            MachineListScreen(
                title: page.title,
                intro: "These are the boxed jobs on the charts. Nothing here can be changed.",
                rows: desk.containers,
                note: desk.containerNote,
                theme: theme,
                wide: wide
            )
        }
    }
}
