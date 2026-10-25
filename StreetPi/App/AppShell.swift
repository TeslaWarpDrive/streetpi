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
    var onRefresh: @MainActor () async -> Void = {}

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.streetPiStill) private var still
    @State private var showAlerts: Bool
    @State private var roomPath: [HouseGroup] = []

    init(
        section: AppSection,
        screen: HouseScreen,
        now: Date,
        onSection: @escaping (AppSection) -> Void,
        desk: DNSDesk = .houseFixture,
        dnsPage: DNSPage? = nil,
        machine: MachineDesk = .houseFixture,
        machinePage: MachinePage? = nil,
        pendingAction: HouseholdAction? = nil,
        passwordSaved: Bool = true,
        showsSetup: Bool = false,
        dnsProblem: PiholeProblem? = nil,
        sessionActive: Bool = false,
        onDNSPage: @escaping (DNSPage?) -> Void = { _ in },
        onMachinePage: @escaping (MachinePage?) -> Void = { _ in },
        onPending: @escaping (HouseholdAction?) -> Void = { _ in },
        onConfirm: @escaping (HouseholdAction) -> Void = { _ in },
        onSavePassword: @escaping () -> Void = {},
        onSetupSave: @escaping (String) -> Void = { _ in },
        onSetupCancel: @escaping () -> Void = {},
        onRefresh: @escaping @MainActor () async -> Void = {}
    ) {
        self.section = section
        self.screen = screen
        self.now = now
        self.onSection = onSection
        self.desk = desk
        self.dnsPage = dnsPage
        self.machine = machine
        self.machinePage = machinePage
        self.pendingAction = pendingAction
        self.passwordSaved = passwordSaved
        self.showsSetup = showsSetup
        self.dnsProblem = dnsProblem
        self.sessionActive = sessionActive
        self.onDNSPage = onDNSPage
        self.onMachinePage = onMachinePage
        self.onPending = onPending
        self.onConfirm = onConfirm
        self.onSavePassword = onSavePassword
        self.onSetupSave = onSetupSave
        self.onSetupCancel = onSetupCancel
        self.onRefresh = onRefresh
        _showAlerts = State(initialValue: section == .alerts)
    }

    private var theme: StreetTheme { .house }

    private var status: PlainEnglishStatus {
        screen.status(now: now)
    }

    private var groups: [GroupBrief] {
        guard let snapshot = screen.snapshot else { return [] }
        return HouseGuide.groups(in: snapshot)
    }

    private var tabBinding: Binding<HouseTab> {
        Binding(
            get: { HouseTab(section: section) },
            set: { next in
                if next == .house {
                    roomPath = []
                }
                onSection(next.section)
            }
        )
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
        .sheet(
            isPresented: Binding(
                get: { showAlerts && still == false },
                set: { showAlerts = $0 }
            )
        ) {
            alerts
        }
    }

    private func shell(wide: Bool) -> some View {
        tabView(wide: wide)
            .environment(\.horizontalSizeClass, wide ? .regular : .compact)
            .modifier(HouseTabChrome(wide: wide, selection: tabBinding))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(theme.background)
    }

    private func tabView(wide: Bool) -> some View {
        TabView(selection: tabBinding) {
            Tab(HouseTab.house.title, systemImage: HouseTab.house.symbol, value: HouseTab.house) {
                house(wide: wide)
            }
            Tab(HouseTab.adBlocker.title, systemImage: HouseTab.adBlocker.symbol, value: HouseTab.adBlocker) {
                adBlocker(wide: wide)
            }
            Tab(HouseTab.pi.title, systemImage: HouseTab.pi.symbol, value: HouseTab.pi) {
                pi(wide: wide)
            }
            Tab(HouseTab.settings.title, systemImage: HouseTab.settings.symbol, value: HouseTab.settings) {
                settings
            }
        }
    }

    private func house(wide: Bool) -> some View {
        AfterglowScope {
            NavigationStack(path: $roomPath) {
                houseBody(wide: wide)
                    .toolbar(.hidden, for: .navigationBar)
                    .navigationDestination(for: HouseGroup.self) { group in
                        room(group, wide: wide)
                    }
            }
        }
        .overlay {
            if still && showAlerts {
                alerts
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(theme.background)
            }
        }
    }

    @ViewBuilder
    private func houseBody(wide: Bool) -> some View {
        HouseHome(
            snapshot: screen.snapshot,
            status: status,
            lines: lines,
            groups: groups,
            alertCount: machine.alerts.count,
            now: now,
            wide: wide,
            onRefresh: onRefresh,
            onAlerts: { showAlerts = true },
            onOpen: openRoom
        )
    }

    @ViewBuilder
    private func room(_ group: HouseGroup, wide: Bool) -> some View {
        if let brief = groups.first(where: { $0.id == group }) {
            GroupDashboard(
                theme: theme,
                brief: brief,
                machine: screen.snapshot?.machine,
                wide: wide
            )
            .navigationTitle(brief.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar)
        }
    }

    private func openRoom(_ group: HouseGroup) {
        switch group {
        case .adBlockerAndDNS:
            roomPath = []
            onSection(.group(.adBlockerAndDNS))
        case .piHealth:
            roomPath = []
            onSection(.group(.piHealth))
        default:
            roomPath = [group]
        }
    }

    private func adBlocker(wide: Bool) -> some View {
        NavigationStack {
            VStack(spacing: 0) {
                if wide == false, dnsPage != nil, showsSetup == false, dnsProblem == nil {
                    NestedBack(title: "Ad blocker") { onDNSPage(nil) }
                }
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
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(theme.background)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func pi(wide: Bool) -> some View {
        NavigationStack {
            VStack(spacing: 0) {
                if wide == false, machinePage != nil {
                    NestedBack(title: "Pi") { onMachinePage(nil) }
                }
                MachineDeskDetail(
                    wide: wide,
                    splits: splitsDesk,
                    desk: machine,
                    page: machinePage,
                    machine: screen.snapshot?.machine,
                    theme: theme,
                    onPage: onMachinePage
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(theme.background)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var settings: some View {
        NavigationStack {
            SettingsView(theme: theme)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(theme.background)
                .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var alerts: some View {
        AlertsSheet(alerts: machine.alerts, theme: theme, wide: false) {
            showAlerts = false
        }
    }

    private var splitsDesk: Bool {
        dynamicTypeSize.isAccessibilitySize == false
    }

    private var lines: [String] {
        guard let snapshot = screen.snapshot, snapshot.isEmptyHouse == false else { return [] }
        return HouseholdVoice.porchLines(snapshot)
    }
}

/// Native tab bar at ordinary sizes. At the largest sizes, a strip that can wrap or scroll.
private struct HouseTabChrome: ViewModifier {
    var wide: Bool
    var selection: Binding<HouseTab>

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func body(content: Content) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            content
                .tabViewStyle(.tabBarOnly)
                .toolbar(.hidden, for: .tabBar)
                .safeAreaInset(edge: wide ? .leading : .bottom, spacing: 0) {
                    AccessibleTabStrip(selection: selection, scrollsHorizontally: wide == false)
                }
        } else {
            content.tabViewStyle(.sidebarAdaptable)
        }
    }
}

/// Back control for a phone page that already has its own title.
private struct NestedBack: View {
    var title: String
    var action: () -> Void

    var body: some View {
        HStack {
            IconChromeButton(title: title, systemImage: "chevron.backward", action: action)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Rhythm.page)
        .padding(.top, Rhythm.tight)
    }
}
