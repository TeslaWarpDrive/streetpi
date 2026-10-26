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
    var actionNotice: ActionNotice?
    var passwordSaved: Bool = true
    var showsSetup: Bool = false
    var dnsProblem: PiholeProblem?
    var sessionActive: Bool = false
    var trustNote: String?
    var offersSetup = false
    var onTrustNewCertificate: () -> Void = {}
    var onKeepSavedPin: () -> Void = {}
    var onSettingsSaved: () -> Void = {}
    var onDNSPage: (DNSPage?) -> Void = { _ in }
    var onMachinePage: (MachinePage?) -> Void = { _ in }
    var onPending: (HouseholdAction?) -> Void = { _ in }
    var onConfirm: (HouseholdAction) -> Void = { _ in }
    var onSavePassword: () -> Void = {}
    var onSetupSave: (String) -> Void = { _ in }
    var onSetupCancel: () -> Void = {}
    var onRefresh: @MainActor () async -> Void = {}
    var piHost: Binding<String> = .constant(LiveEndpoints.house.netdata.absoluteString)
    var hostNote: String?
    var onCommitHost: () -> Void = {}
    var piNotice: String?
    var machineReading: MachineReading?
    var statusBoard: HouseStatusBoard?
    var statusAddress: String = LiveEndpoints.house.uptimeKuma.absoluteString
    var statusSlug: String = "house"
    var onStatusPage: (String, String) -> Void = { _, _ in }

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
        actionNotice: ActionNotice? = nil,
        passwordSaved: Bool = true,
        showsSetup: Bool = false,
        dnsProblem: PiholeProblem? = nil,
        sessionActive: Bool = false,
        trustNote: String? = nil,
        offersSetup: Bool = false,
        onTrustNewCertificate: @escaping () -> Void = {},
        onKeepSavedPin: @escaping () -> Void = {},
        onSettingsSaved: @escaping () -> Void = {},
        onDNSPage: @escaping (DNSPage?) -> Void = { _ in },
        onMachinePage: @escaping (MachinePage?) -> Void = { _ in },
        onPending: @escaping (HouseholdAction?) -> Void = { _ in },
        onConfirm: @escaping (HouseholdAction) -> Void = { _ in },
        onSavePassword: @escaping () -> Void = {},
        onSetupSave: @escaping (String) -> Void = { _ in },
        onSetupCancel: @escaping () -> Void = {},
        onRefresh: @escaping @MainActor () async -> Void = {},
        piHost: Binding<String> = .constant(LiveEndpoints.house.netdata.absoluteString),
        hostNote: String? = nil,
        onCommitHost: @escaping () -> Void = {},
        piNotice: String? = nil,
        machineReading: MachineReading? = nil,
        statusBoard: HouseStatusBoard? = nil,
        statusAddress: String = LiveEndpoints.house.uptimeKuma.absoluteString,
        statusSlug: String = "house",
        onStatusPage: @escaping (String, String) -> Void = { _, _ in }
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
        self.actionNotice = actionNotice
        self.passwordSaved = passwordSaved
        self.showsSetup = showsSetup
        self.dnsProblem = dnsProblem
        self.sessionActive = sessionActive
        self.trustNote = trustNote
        self.offersSetup = offersSetup
        self.onTrustNewCertificate = onTrustNewCertificate
        self.onKeepSavedPin = onKeepSavedPin
        self.onSettingsSaved = onSettingsSaved
        self.onDNSPage = onDNSPage
        self.onMachinePage = onMachinePage
        self.onPending = onPending
        self.onConfirm = onConfirm
        self.onSavePassword = onSavePassword
        self.onSetupSave = onSetupSave
        self.onSetupCancel = onSetupCancel
        self.onRefresh = onRefresh
        self.piHost = piHost
        self.hostNote = hostNote
        self.onCommitHost = onCommitHost
        self.piNotice = piNotice
        self.machineReading = machineReading
        self.statusBoard = statusBoard
        self.statusAddress = statusAddress
        self.statusSlug = statusSlug
        self.onStatusPage = onStatusPage
        _showAlerts = State(initialValue: section == .alerts)
    }

    private var theme: StreetTheme { .house }

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
        ShellChrome(wide: wide, selection: tabBinding, roomy: dynamicTypeSize.isAccessibilitySize) {
            tabs(wide: wide)
        }
        .modifier(WideSizeClass(wide: wide))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(theme.background)
    }

    @ViewBuilder
    private func tabs(wide: Bool) -> some View {
        switch HouseTab(section: section) {
        case .house:
            house(wide: wide)
        case .adBlocker:
            adBlocker(wide: wide)
        case .pi:
            pi(wide: wide)
        case .settings:
            settings
        }
    }

    private func house(wide: Bool) -> some View {
        AfterglowScope {
            NavigationStack(path: $roomPath) {
                houseBody(wide: wide)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .toolbar(.hidden, for: .navigationBar)
                    .navigationDestination(for: HouseGroup.self) { group in
                        room(group, wide: wide)
                    }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
            board: houseBoard,
            alertCount: machine.alerts.count,
            wide: wide,
            onRefresh: onRefresh,
            onAlerts: { showAlerts = true },
            onSettings: { onSection(.settings) },
            onOpen: openRoom,
            onOpenBlocker: openBlockerDetail,
            onPauseBlocker: pauseBlocker,
            onOpenDevices: openDevices
        )
    }

    private func openBlockerDetail() {
        roomPath = []
        onDNSPage(.today)
        onSection(.group(.adBlockerAndDNS))
    }

    private func pauseBlocker() {
        let board = HouseBoard.make(screen: screen, desk: desk, now: now, piNotice: piNotice)
        guard board.blocker.canPause else { return }
        onPending(.pauseAdBlocking(.thirtySeconds))
    }

    private func openDevices() {
        roomPath = []
        onDNSPage(.clients)
        onSection(.group(.adBlockerAndDNS))
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
                    trustNote: trustNote,
                    offersSetup: offersSetup,
                    onTrustNewCertificate: onTrustNewCertificate,
                    onKeepSavedPin: onKeepSavedPin,
                    actionNotice: actionNotice,
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
                    machine: machineReading ?? screen.snapshot?.machine,
                    theme: theme,
                    piNotice: piNotice,
                    onPage: onMachinePage
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(theme.background)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var houseBoard: ControlBoard {
        let board = HouseBoard.make(screen: screen, desk: desk, now: now, piNotice: piNotice)
        guard let statusBoard else { return board }
        return HouseBoard.applying(status: statusBoard, to: board)
    }

    private var settings: some View {
        NavigationStack {
            SettingsView(
                theme: theme,
                piHost: piHost,
                hostNote: hostNote,
                onCommitHost: onCommitHost,
                onSaved: onSettingsSaved,
                statusAddress: statusAddress,
                statusSlug: statusSlug,
                onStatusPage: onStatusPage
            )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(theme.background)
                .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var alerts: some View {
        AlertsSheet(alerts: machine.alerts, note: machine.alertNote, theme: theme, wide: false) {
            showAlerts = false
        }
    }

    private var splitsDesk: Bool {
        dynamicTypeSize.isAccessibilitySize == false
    }
}

/// Regular width is the iPad. Compact stays with the phone, so tab content keeps its height.
private struct WideSizeClass: ViewModifier {
    var wide: Bool

    func body(content: Content) -> some View {
        if wide {
            content.environment(\.horizontalSizeClass, .regular)
        } else {
            content
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
