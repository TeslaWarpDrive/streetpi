import SwiftUI
import StreetPiCore

struct AppShell: View {
    var section: AppSection
    var screen: HouseScreen
    var now: Date
    var onSection: (AppSection) -> Void
    var desk: DNSDesk = .houseFixture
    var dnsPage: DNSPage?
    var machine: MachineDesk = .houseFixture
    var machinePage: MachinePage?
    var pendingAction: HouseholdAction?
    var passwordSaved: Bool = true
    var showsSetup: Bool = false
    var dnsProblem: PiholeProblem?
    var sessionActive: Bool = false
    var onDNSPage: (DNSPage?) -> Void = { _ in }
    var onMachinePage: (MachinePage?) -> Void = { _ in }
    var onPending: (HouseholdAction?) -> Void = { _ in }
    var onConfirm: (HouseholdAction) -> Void = { _ in }
    var onSavePassword: () -> Void = {}
    var onSetupSave: (String) -> Void = { _ in }
    var onSetupCancel: () -> Void = {}
    var statusBoard: HouseStatusBoard? = nil
    var statusEndpoint: StatusPageEndpoint = .house
    var onStatusEndpoint: (StatusPageEndpoint) -> Void = { _ in }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.streetPiStill) private var still

    private var calm: Animation? {
        (reduceMotion || still) ? nil : .easeInOut(duration: 0.28)
    }

    private var theme: StreetTheme {
        .house
    }

    private var status: PlainEnglishStatus {
        if statusBoard?.isMissing == true {
            return PlainEnglishStatus(
                headline: StatusPageCopy.notSetUp,
                detail: StatusPageCopy.notSetUpDetail,
                tone: .attention,
                linkLine: "On the home network"
            )
        }
        return screen.status(now: now)
    }

    private var groups: [GroupBrief] {
        if let statusBoard {
            return statusBoard.tiles.map(\.brief)
        }
        guard let snapshot = screen.snapshot else { return [] }
        return HouseGuide.groups(in: snapshot)
    }

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()
            GeometryReader { proxy in
                shell(wide: proxy.size.width >= 700)
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            }
            if let pendingAction {
                ActionConfirm(
                    action: pendingAction,
                    theme: theme,
                    onCancel: { onPending(nil) },
                    onConfirm: { onConfirm(pendingAction) }
                )
            }
        }
        .tint(theme.accent)
    }

    private func shell(wide: Bool) -> some View {
        Group {
            if wide {
                NavigationSplitView {
                    sidebar
                        .navigationSplitViewColumnWidth(
                            min: dynamicTypeSize.isAccessibilitySize ? 280 : 216,
                            ideal: dynamicTypeSize.isAccessibilitySize ? 360 : 260,
                            max: 460
                        )
                        .toolbar(.hidden, for: .navigationBar)
                } detail: {
                    detail(wide: true)
                        .toolbar(.hidden, for: .navigationBar)
                        .background {
                            if section == .home {
                                HomeAura(tone: status.tone)
                            }
                        }
                }
                .navigationSplitViewStyle(.balanced)
                .environment(\.horizontalSizeClass, .regular)
            } else {
                VStack(spacing: 0) {
                    phoneChrome
                    detail(wide: false)
                }
                .environment(\.horizontalSizeClass, .compact)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            if section == .home {
                HomeAura(tone: status.tone)
            } else {
                theme.background
            }
        }
    }

    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Rhythm.line) {
                Text("Raspberry Pi Stats")
                    .font(.system(.title3, design: .rounded))
                    .foregroundStyle(theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, Rhythm.line)
                    .accessibilityAddTraits(.isHeader)
                sidebarButton("Home", section: .home)
                ForEach(groups) { group in
                    sidebarButton(group.title, section: .group(group.id))
                }
                sidebarButton("Alerts", section: .alerts)
                sidebarButton("Settings", section: .settings)
            }
            .padding(Rhythm.page)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .background(theme.surface)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Sections")
    }

    private func sidebarButton(_ title: String, section target: AppSection) -> some View {
        let selected = section == target
        return Button(title) {
            onSection(target)
        }
        .font(.body.weight(selected ? .semibold : .regular))
        .foregroundStyle(selected ? theme.ink : theme.secondary)
        .multilineTextAlignment(.leading)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            selected ? theme.background : Color.clear,
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var phoneChrome: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Rhythm.line) {
                chromeTitleText
                Spacer(minLength: Rhythm.line)
                chromeButton
            }
            VStack(alignment: .leading, spacing: Rhythm.tight) {
                HStack {
                    Spacer(minLength: 0)
                    chromeButton
                }
                chromeTitleText
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, Rhythm.page)
        .padding(.top, Rhythm.tight)
    }

    private var chromeTitleText: some View {
        Text(chromeTitle)
            .font(.subheadline)
            .foregroundStyle(theme.secondary)
            .multilineTextAlignment(.leading)
            .lineLimit(3)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var chromeTitle: String {
        switch section {
        case .home, .settings:
            "Raspberry Pi Stats"
        case .alerts:
            "Alerts"
        case .group(let group):
            nestedTitle(group)
        }
    }

    private func nestedTitle(_ group: HouseGroup) -> String {
        if group == .adBlockerAndDNS, let dnsPage {
            return dnsPage.title
        }
        if group == .piHealth, let machinePage {
            return machinePage.title
        }
        if let brief = groups.first(where: { $0.id == group }) {
            return brief.title
        }
        return group.title
    }

    @ViewBuilder
    private var chromeButton: some View {
        switch section {
        case .group(let group):
            groupBack(group)
        case .settings, .alerts:
            IconChromeButton(title: "Home", systemImage: "house") {
                onSection(.home)
            }
        case .home:
            ChromeButtonPair(
                first: IconChromeButton(title: "Alerts", systemImage: "bell") {
                    onSection(.alerts)
                },
                second: IconChromeButton(title: "Settings", systemImage: "gearshape") {
                    onSection(.settings)
                }
            )
        }
    }

    @ViewBuilder
    private func groupBack(_ group: HouseGroup) -> some View {
        if group == .adBlockerAndDNS, dnsPage != nil {
            IconChromeButton(title: "Ad blocker & DNS", systemImage: "chevron.backward") {
                onDNSPage(nil)
            }
        } else if group == .piHealth, machinePage != nil {
            IconChromeButton(title: "Pi health", systemImage: "chevron.backward") {
                onMachinePage(nil)
            }
        } else {
            IconChromeButton(title: "Home", systemImage: "chevron.backward") {
                onSection(.home)
            }
        }
    }

    private var splitsDesk: Bool {
        !dynamicTypeSize.isAccessibilitySize
    }

    @ViewBuilder
    private func detail(wide: Bool) -> some View {
        detailBody(wide: wide)
            .animation(calm, value: section)
            .animation(calm, value: dnsPage)
            .animation(calm, value: machinePage)
    }

    @ViewBuilder
    private func detailBody(wide: Bool) -> some View {
        switch section {
        case .home:
            HomeView(
                theme: theme,
                snapshot: screen.snapshot,
                status: status,
                lines: lines,
                groups: groups,
                wide: wide,
                onGroup: { onSection(.group($0)) }
            )
        case .alerts:
            AlertsScreen(alerts: machine.alerts, theme: theme, wide: wide)
        case .group(let group):
            if group == .adBlockerAndDNS {
                DNSDeskDetail(
                    wide: wide,
                    splits: splitsDesk,
                    desk: desk,
                    page: dnsPage,
                    theme: theme,
                    now: now,
                    passwordSaved: passwordSaved,
                    sessionActive: sessionActive,
                    showsSetup: showsSetup,
                    problem: dnsProblem,
                    onPage: onDNSPage,
                    onPending: onPending,
                    onSavePassword: onSavePassword,
                    onSetupSave: onSetupSave,
                    onSetupCancel: onSetupCancel
                )
            } else if group == .piHealth {
                MachineDeskDetail(
                    wide: wide,
                    splits: splitsDesk,
                    desk: machine,
                    page: machinePage,
                    machine: screen.snapshot?.machine,
                    theme: theme,
                    onPage: onMachinePage
                )
            } else if let brief = groups.first(where: { $0.id == group }) {
                GroupDashboard(
                    theme: theme,
                    brief: brief,
                    machine: screen.snapshot?.machine,
                    wide: wide
                )
            } else {
                HomeView(
                    theme: theme,
                    snapshot: nil,
                    status: PlainEnglishStatus(
                        headline: "Nothing in \(group.title) yet.",
                        detail: nil,
                        tone: .calm,
                        linkLine: status.linkLine
                    ),
                    lines: [],
                    groups: [],
                    wide: wide,
                    onGroup: { _ in }
                )
            }
        case .settings:
            SettingsView(theme: theme, endpoint: statusEndpoint, onEndpoint: onStatusEndpoint)
        }
    }

    private var lines: [String] {
        if statusBoard?.isMissing == true { return [] }
        guard let snapshot = screen.snapshot, !snapshot.isEmptyHouse else { return [] }
        return HouseholdVoice.porchLines(snapshot)
    }
}
