import StreetPiCore
import SwiftUI

struct DNSToday: View {
    var desk: DNSDesk
    var theme: StreetTheme
    var wide: Bool
    var onAction: (HouseholdAction) -> Void

    private var share: LookupShare {
        LookupShare.from(desk: desk)
    }

    var body: some View {
        DeskScroll(wide: wide) {
            DNSBlockerHero(
                share: share,
                enabled: desk.blocking.enabled,
                blockingLine: desk.blockingLine,
                theme: theme
            )
            DNSMeaningCard(share: share, theme: theme)
            DNSStatRow(share: share, theme: theme)
            DNSPauseChoices(desk: desk, theme: theme, onAction: onAction)
            day
        }
    }

    @ViewBuilder
    private var day: some View {
        if desk.hasDayLookups {
            StoppedHourChart(samples: desk.day, stopped: share.stopped, theme: theme)
        } else {
            EmptyNote(title: DNSCopy.emptyChartTitle, detail: DNSCopy.emptyChartDetail, theme: theme)
        }
    }
}
