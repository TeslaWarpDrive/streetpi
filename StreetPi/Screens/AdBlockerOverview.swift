import StreetPiCore
import SwiftUI

/// The ad blocker at a glance: the share it stopped, what that means, the three counts,
/// the pause lengths, and the hours. The Home card opens it as a sheet, and it is the first
/// page of the Ad blocker tab. Every big number opens a plain-English explainer.
struct AdBlockerOverview<More: View>: View {
    var desk: DNSDesk
    var theme: StreetTheme
    var wide: Bool
    var title: String = "Ad blocker"
    var onAction: (HouseholdAction) -> Void
    var onClose: (() -> Void)?
    @ViewBuilder var more: () -> More

    @Environment(\.afterglowPalette) private var palette
    @State private var explainer: NumberExplainer?

    private var share: LookupShare {
        LookupShare.from(desk: desk)
    }

    var body: some View {
        ScrollView {
            FitOfferedWidth(maxWidth: wide ? 880 : nil) {
                VStack(alignment: .leading, spacing: AfterglowShape.line) {
                    header
                    BlockerHeroCard(
                        share: share,
                        enabled: desk.blocking.enabled,
                        blockingLine: desk.blockingLine
                    ) {
                        explainer = AdBlockerCopy.percent(share)
                    }
                    MeaningPanel(share: share)
                    CountTiles(share: share) { explainer = $0 }
                    PausePills(enabled: desk.blocking.enabled, onAction: onAction)
                        .padding(.top, AfterglowShape.tight)
                    hours
                        .padding(.top, AfterglowShape.tight)
                    more()
                }
                .padding(.horizontal, wide ? AfterglowShape.page : 16)
                .padding(.top, AfterglowShape.tight)
                .padding(.bottom, AfterglowShape.block)
            }
        }
        .scrollIndicators(.hidden)
        .background(palette.ground.ignoresSafeArea())
        .sheet(item: $explainer) { item in
            PercentMeaningSheet(title: item.title, text: item.text) {
                explainer = nil
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: AfterglowShape.line) {
            Text(title)
                .font(.system(.largeTitle, design: .rounded).bold())
                .foregroundStyle(palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let onClose {
                IconChromeButton(title: "Close", systemImage: "xmark", action: onClose)
            }
        }
        .padding(.vertical, AfterglowShape.tight)
    }

    @ViewBuilder
    private var hours: some View {
        if desk.hasDayLookups {
            HourBars(samples: desk.day, stopped: share.stopped)
        } else {
            EmptyNote(title: DNSCopy.emptyChartTitle, detail: DNSCopy.emptyChartDetail, theme: theme)
        }
    }
}

extension AdBlockerOverview where More == EmptyView {
    init(
        desk: DNSDesk,
        theme: StreetTheme,
        wide: Bool,
        title: String = "Ad blocker",
        onAction: @escaping (HouseholdAction) -> Void,
        onClose: (() -> Void)? = nil
    ) {
        self.init(
            desk: desk,
            theme: theme,
            wide: wide,
            title: title,
            onAction: onAction,
            onClose: onClose,
            more: { EmptyView() }
        )
    }
}
