import SwiftUI
import StreetPiCore

struct RootView: View {
    @State private var clock: Date
    @State private var screen = HouseScreen.ready(.healthyFixture)
    @State private var section = AppSection.home
    @State private var desk = DNSDesk.houseFixture
    @State private var dnsPage: DNSPage?
    @State private var dnsDirectory = false
    @State private var machine = MachineDesk.houseFixture
    @State private var machinePage: MachinePage?
    @State private var pending: HouseholdAction?
    @State private var passwordSaved = false
    @State private var showsSetup = false
    @State private var dnsSession = DNSSessionHold()
    @State private var showLaunch: Bool
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.secretStore) private var secretStore

    init(now: Date) {
        _clock = State(initialValue: now)
        let testing = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        _showLaunch = State(initialValue: !testing)
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
            showsDNSDirectory: dnsDirectory,
            machine: machine,
            machinePage: machinePage,
            pendingAction: pending,
            passwordSaved: passwordSaved,
            showsSetup: showsSetup,
            sessionActive: dnsSession.client != nil,
            onDNSPage: { dnsPage = $0 },
            onDNSDirectory: { dnsDirectory = $0 },
            onMachinePage: { machinePage = $0 },
            onPending: { pending = $0 },
            onConfirm: { action in
                Task { await confirm(action) }
            },
            onSavePassword: { showsSetup = true },
            onSetupSave: saveSetup,
            onSetupCancel: { showsSetup = false },
            onRefresh: refreshNow
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
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            let stored = try? secretStore.load(for: AppPassword.account)
            passwordSaved = stored != nil
            await watchHouse()
        }
    }

    /// Fixture refresh only. The poller is an actor, and the live socket stays off.
    private func watchHouse() async {
        let poller = HousePoller {
            try await HouseholdStatusLoader.healthyFixture(now: { Date() }).load()
        }
        while !Task.isCancelled {
            let tick = await poller.tick()
            apply(tick)
            try? await Task.sleep(for: .seconds(tick.waitSeconds))
        }
    }

    private func refreshNow() async {
        let poller = HousePoller {
            try await HouseholdStatusLoader.healthyFixture(now: { Date() }).load()
        }
        apply(await poller.tick())
    }

    private func apply(_ tick: HousePollTick) {
        if tick.unreachable {
            screen = .failed
        } else if let snapshot = tick.snapshot {
            clock = Date()
            screen = .ready(snapshot)
        }
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
