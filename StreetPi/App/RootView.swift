import SwiftUI
import StreetPiCore

struct RootView: View {
    @State private var clock: Date
    @State private var screen: HouseScreen
    @State private var section = AppSection.home
    @State private var desk = DNSDesk.houseFixture
    @State private var dnsPage: DNSPage?
    @State private var machine = MachineDesk.houseFixture
    @State private var machinePage: MachinePage?
    @State private var pending: HouseholdAction?
    @State private var passwordSaved = false
    @State private var showsSetup = false
    @State private var dnsSession = DNSSessionHold()
    @State private var showLaunch: Bool
    @State private var statusEndpoint: StatusPageEndpoint
    @State private var statusBoard: HouseStatusBoard?
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.secretStore) private var secretStore

    init(now: Date) {
        _clock = State(initialValue: now)
        let testing = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        _showLaunch = State(initialValue: !testing)
        _screen = State(initialValue: testing ? .ready(.healthyFixture) : .empty)
        _statusEndpoint = State(initialValue: testing ? .house : StatusPageStore.current())
        _statusBoard = State(initialValue: nil)
    }

    var body: some View {
        AppShell(
            section: section,
            screen: screen,
            now: clock,
            onSection: { next in
                section = next
                if next != .group(.adBlockerAndDNS) {
                    dnsPage = nil
                }
                if next != .group(.piHealth) {
                    machinePage = nil
                }
            },
            desk: desk,
            dnsPage: dnsPage,
            machine: machine,
            machinePage: machinePage,
            pendingAction: pending,
            passwordSaved: passwordSaved,
            showsSetup: showsSetup,
            sessionActive: dnsSession.client != nil,
            onDNSPage: { dnsPage = $0 },
            onMachinePage: { machinePage = $0 },
            onPending: { pending = $0 },
            onConfirm: { action in
                Task { await confirm(action) }
            },
            onSavePassword: { showsSetup = true },
            onSetupSave: saveSetup,
            onSetupCancel: { showsSetup = false },
            statusBoard: statusBoard,
            statusEndpoint: statusEndpoint,
            onStatusEndpoint: saveStatusEndpoint
        )
        .launchOverlay(isPresented: $showLaunch)
        .preferredColorScheme(.dark)
        .environment(\.secretStore, KeychainSecretStore())
        .onChange(of: scenePhase) { _, phase in
            guard phase == .background else { return }
            let client = dnsSession.client
            Task {
                await client?.appDidEnterBackground()
            }
        }
        .task(id: watchKey) {
            guard scenePhase == .active else { return }
            let stored = try? secretStore.load(for: AppPassword.account)
            passwordSaved = stored != nil
            await watchHouse()
        }
    }

    private var watchKey: String {
        "\(scenePhase) \(statusEndpoint.host) \(statusEndpoint.port) \(statusEndpoint.slug)"
    }

    private static var underTest: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    private func watchHouse() async {
        if HouseRefreshSource.choose(underTest: Self.underTest) == .fixtures {
            let poller = HousePoller {
                try await HouseholdStatusLoader.healthyFixture(now: { Date() }).load()
            }
            await apply(poller, hold: nil)
            return
        }
        let endpoint = statusEndpoint
        let hold = StatusPageHold()
        let poller = HousePoller {
            let reader = StatusPageReader(
                transport: StatusPageURLSession(endpoint: endpoint),
                endpoint: endpoint,
                now: { Date() }
            )
            let load = try await reader.load()
            hold.store(load.board)
            return load.snapshot
        }
        await apply(poller, hold: hold)
    }

    private func apply(_ poller: HousePoller, hold: StatusPageHold?) async {
        while !Task.isCancelled {
            let tick = await poller.tick()
            if tick.unreachable {
                screen = .failed
                statusBoard = nil
            } else if let snapshot = tick.snapshot {
                clock = Date()
                screen = .ready(snapshot)
                if let board = hold?.take() {
                    statusBoard = board
                }
            }
            try? await Task.sleep(for: .seconds(tick.waitSeconds))
        }
    }

    private func saveStatusEndpoint(_ endpoint: StatusPageEndpoint) {
        statusEndpoint = endpoint
        StatusPageStore.save(endpoint)
    }

    private func saveSetup(_ raw: String) {
        guard !raw.isEmpty else { return }
        do {
            try secretStore.save(Data(raw.utf8), for: AppPassword.account)
            let pin = Data(PiholeCertificate.houseFixture.sha256Fingerprint.utf8)
            try secretStore.save(pin, for: AppPassword.certificatePin)
            passwordSaved = true
            showsSetup = false
        } catch {
            showsSetup = true
        }
    }

    private func confirm(_ action: HouseholdAction) async {
        let policy = ActionPolicy.confirmation(for: action)
        if policy.requiresFaceID {
            let reason = policy.explanation ?? "Confirm this change."
            let allowed = await FaceIDGate.allow(reason: reason)
            guard allowed else { return }
        }
        if case .signOutOfAdBlocker = action {
            await dnsSession.client?.signOut()
        } else {
            desk = desk.applying(action)
        }
        pending = nil
    }
}
