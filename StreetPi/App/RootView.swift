import SwiftUI
import StreetPiCore

struct RootView: View {
    @State private var clock: Date
    @State private var screen: HouseScreen
    @State private var section = AppSection.home
    @State private var desk = DNSDesk.houseFixture
    @State private var dnsPage: DNSPage?
    @State private var machine: MachineDesk
    @State private var machinePage: MachinePage?
    @State private var pending: HouseholdAction?
    @State private var passwordSaved = false
    @State private var showsSetup = false
    @State private var dnsSession = DNSSessionHold()
    @State private var showLaunch: Bool
    @State private var piHost: String
    @State private var committedHost: String
    @State private var hostNote: String?
    @State private var piNotice: String?
    @State private var liveReading: MachineReading?
    @State private var liveClient: LiveHTTPClient
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.secretStore) private var secretStore

    init(now: Date) {
        _clock = State(initialValue: now)
        let fixtures = LiveGate.usesFixtures
        _showLaunch = State(initialValue: !fixtures)
        let store = LiveHostStore()
        let netdata = store.netdataText()
        _piHost = State(initialValue: netdata)
        _committedHost = State(initialValue: netdata)
        _hostNote = State(initialValue: nil)
        _liveClient = State(initialValue: LiveHTTPClient(store: store))
        if fixtures {
            _screen = State(initialValue: .ready(.healthyFixture))
            _machine = State(initialValue: .houseFixture)
            _piNotice = State(initialValue: nil)
            _liveReading = State(initialValue: HouseholdSnapshot.healthyFixture.machine)
        } else {
            var house = HouseholdSnapshot.healthyFixture
            house.machine = nil
            _screen = State(initialValue: .ready(house))
            _machine = State(initialValue: .livePlaceholder)
            _piNotice = State(initialValue: HouseReadingCopy.lookingTitle)
            _liveReading = State(initialValue: nil)
        }
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
            piHost: $piHost,
            hostNote: hostNote,
            onCommitHost: commitPiHost,
            piNotice: piNotice
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
        "\(scenePhase)|\(committedHost)"
    }

    private func watchHouse() async {
        if LiveGate.usesFixtures {
            await watchFixtures()
        } else {
            await watchLive()
        }
    }

    /// Snapshot and preview path. This loop never opens a socket.
    private func watchFixtures() async {
        let poller = HousePoller {
            try await HouseholdStatusLoader.healthyFixture(now: { Date() }).load()
        }
        while !Task.isCancelled {
            let tick = await poller.tick()
            if tick.unreachable {
                screen = .failed
            } else if let snapshot = tick.snapshot {
                clock = Date()
                screen = .ready(snapshot)
            }
            try? await Task.sleep(for: .seconds(tick.waitSeconds))
        }
    }

    private func watchLive() async {
        async let house: Void = pumpHouse()
        async let meters: Void = pumpMeters()
        _ = await (house, meters)
    }

    private func pumpHouse() async {
        let poller = HousePoller {
            var snapshot = try await HouseholdStatusLoader.healthyFixture(now: { Date() }).load()
            snapshot.machine = nil
            return snapshot
        }
        while !Task.isCancelled {
            let tick = await poller.tick()
            if let snapshot = tick.snapshot {
                showHouse(snapshot)
            }
            try? await Task.sleep(for: .seconds(tick.waitSeconds))
        }
    }

    private func pumpMeters() async {
        var failures = 0
        while !Task.isCancelled {
            let base = LiveHostStore().load().netdata
            guard let result = await PiMeterRefresh(client: liveClient, base: base).load() else { return }
            if Task.isCancelled { return }
            switch result {
            case .success(let meters):
                apply(meters)
                failures = meters.reading.hasSignal ? 0 : failures + 1
            case .failure(let problem):
                liveReading = nil
                piNotice = problem.sentence
                failures += 1
            }
            if let snapshot = screen.snapshot {
                showHouse(snapshot)
            }
            let wait = RefreshPace.waitSeconds(afterFailures: failures)
            try? await Task.sleep(for: .seconds(wait))
        }
    }

    private func apply(_ meters: NetdataMeters) {
        machine.host = meters.hostName
        machine.modelName = "Raspberry Pi"
        if meters.reading.hasSignal {
            liveReading = meters.reading
            piNotice = nil
        } else {
            liveReading = nil
            piNotice = NetdataProblem.notUnderstood.sentence
        }
    }

    private func showHouse(_ snapshot: HouseholdSnapshot) {
        var next = snapshot
        next.machine = liveReading
        next.capturedAt = Date()
        clock = Date()
        screen = .ready(next)
    }

    private func commitPiHost() {
        let store = LiveHostStore()
        guard let url = Self.houseCharts(piHost) else {
            hostNote = "Use the Pi's address on your home network."
            piHost = committedHost
            return
        }
        let current = store.load()
        do {
            try store.save(
                pihole: current.pihole.absoluteString,
                netdata: url.absoluteString,
                uptimeKuma: current.uptimeKuma.absoluteString
            )
        } catch {
            hostNote = "Use the Pi's address on your home network."
            piHost = committedHost
            return
        }
        liveClient.apply(store)
        hostNote = nil
        piHost = store.netdataText()
        committedHost = piHost
    }

    private static func houseCharts(_ text: String) -> URL? {
        guard let url = LiveAddress.validated(text, schemes: ["http", "https"]),
              let host = url.host?.lowercased(),
              !host.contains("netdata.cloud"),
              !host.contains("my-netdata.io")
        else { return nil }
        return url
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
