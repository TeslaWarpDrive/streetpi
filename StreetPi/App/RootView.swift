import SwiftUI
import StreetPiCore

struct RootView: View {
    @State private var clock: Date
    @State private var screen: HouseScreen
    @State private var section = AppSection.home
    @State private var desk: DNSDesk
    @State private var dnsPage: DNSPage?
    @State private var machine: MachineDesk
    @State private var machinePage: MachinePage?
    @State private var pending: HouseholdAction?
    @State private var passwordSaved = false
    @State private var showsSetup = false
    @State private var dnsSession = DNSSessionHold()
    @State private var showLaunch: Bool
    @State private var dnsProblem: PiholeProblem?
    @State private var presentedPin: String?
    @State private var declinedPin: String?
    @State private var signedOut = false
    @State private var retry = 0
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.secretStore) private var secretStore

    init(now: Date) {
        let testing = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        _clock = State(initialValue: now)
        _screen = State(initialValue: testing ? .ready(.healthyFixture) : .empty)
        _desk = State(initialValue: testing ? .houseFixture : .emptyLookups)
        _machine = State(initialValue: testing ? .houseFixture : .unread)
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
            machine: machine,
            machinePage: machinePage,
            pendingAction: pending,
            passwordSaved: passwordSaved,
            showsSetup: showsSetup,
            dnsProblem: dnsProblem,
            sessionActive: dnsSession.signedIn,
            trustNote: setupTrustNote,
            offersSetup: !passwordSaved,
            onTrustNewCertificate: trustPresentedPin,
            onKeepSavedPin: keepSavedPin,
            onSettingsSaved: {
                signedOut = false
                retry += 1
            },
            onDNSPage: { dnsPage = $0 },
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
            signedOut = false
            let client = dnsSession.client
            dnsSession.signedIn = false
            Task { await client?.appDidEnterBackground() }
        }
        .task(id: watchToken) {
            guard scenePhase == .active else { return }
            passwordSaved = (try? KeychainSession(store: secretStore).hasAppPassword()) ?? false
            await watchHouse()
        }
    }

    private var watchToken: String {
        "\(String(describing: scenePhase))-\(retry)-\(signedOut)"
    }

    private var setupTrustNote: String {
        "This phone checks the ad blocker's security pin from Settings. The pin stays on this phone."
    }

    /// Tests keep the fixture screen and never open a socket.
    private func watchHouse() async {
        guard LiveReaderGate.opensSockets, signedOut == false else { return }
        var failures = 0
        while Task.isCancelled == false, signedOut == false {
            let client = await clientForCurrentSettings()
            let board = await refresh(client, now: Date())
            if Task.isCancelled || signedOut { break }
            apply(board)
            failures = board.problem == nil ? 0 : failures + 1
            let wait = RefreshPace.waitSeconds(afterFailures: failures)
            try? await Task.sleep(for: .seconds(wait))
        }
    }

    private func refreshNow() async {
        guard LiveReaderGate.opensSockets, signedOut == false else { return }
        let client = await clientForCurrentSettings()
        apply(await refresh(client, now: Date()))
    }

    private func clientForCurrentSettings() async -> PiholeClient {
        let hosts = LiveHostStore()
        let endpoint = PiholeBaseAddress.endpoint(from: hosts.piholeText()) ?? .house
        let pin = hosts.pinText()
        if let existing = dnsSession.client, dnsSession.endpoint == endpoint, dnsSession.pin == pin {
            dnsSession.http?.apply(hosts)
            return existing
        }
        await dnsSession.client?.signOut()
        let http = LiveHTTPClient(store: hosts)
        http.apply(hosts)
        let box = PresentedPinBox()
        let store = secretStore
        let sessions = KeychainSession(store: store)
        let client = PiholeClient(
            transport: PiholeURLSessionTransport(
                http: http,
                endpoint: endpoint,
                sessions: sessions,
                presented: box
            ),
            password: { AdBlockerSecrets.password(in: store) }
        )
        if let saved = try? sessions.loadSessionID() {
            await client.restoreSession(
                id: saved,
                expiresAt: Date().addingTimeInterval(TimeInterval(FTLSessionPolicy.validitySeconds))
            )
        }
        dnsSession.client = client
        dnsSession.http = http
        dnsSession.endpoint = endpoint
        dnsSession.pin = pin
        dnsSession.presented = box
        dnsSession.signedIn = false
        return client
    }

    private func refresh(_ client: PiholeClient, now: Date) async -> AdBlockerBoard {
        let saved = AdBlockerSecrets.password(in: secretStore).isEmpty == false
        do {
            let state = try await client.reachability()
            guard saved else { return AdBlockerHome.notSetUp(now: now) }
            if state == .dnsOff { return AdBlockerHome.dnsOff(now: now) }
            let load = try await client.loadDesk(now: now)
            dnsSession.signedIn = true
            return AdBlockerHome.ready(load, now: now)
        } catch let problem as PiholeProblem {
            dnsSession.signedIn = false
            if problem == .certificateChanged {
                let presented = dnsSession.presented?.presented()
                if let presented, presented == declinedPin {
                    return AdBlockerHome.failed(.pinKept, now: now)
                }
                presentedPin = presented
                return AdBlockerHome.failed(.certificateChanged, now: now)
            }
            if problem == .needsPassword || problem == .notSetUp {
                return AdBlockerHome.notSetUp(now: now)
            }
            if problem == .offline {
                return AdBlockerHome.offline(now: now)
            }
            return AdBlockerHome.failed(problem, now: now)
        } catch {
            dnsSession.signedIn = false
            return AdBlockerHome.offline(now: now)
        }
    }

    private func apply(_ board: AdBlockerBoard) {
        clock = Date()
        desk = board.desk
        screen = .explained(board.status, board.snapshot)
        dnsProblem = board.problem
        if board.problem != .certificateChanged {
            presentedPin = nil
        }
    }

    private func trustPresentedPin() {
        guard let presentedPin, PiholePin.isSHA256Pin(presentedPin) else { return }
        let hosts = LiveHostStore()
        do {
            try hosts.savePin(presentedPin)
        } catch {
            return
        }
        dnsSession.http?.apply(hosts)
        declinedPin = nil
        self.presentedPin = nil
        signedOut = false
        retry += 1
    }

    private func keepSavedPin() {
        declinedPin = presentedPin ?? declinedPin
        apply(AdBlockerHome.failed(.pinKept, now: Date()))
    }

    private func saveSetup(_ raw: String) {
        guard raw.isEmpty == false else { return }
        do {
            try KeychainSession(store: secretStore).saveAppPassword(raw)
            passwordSaved = true
            showsSetup = false
            signedOut = false
            retry += 1
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
        switch action {
        case .signOutOfAdBlocker:
            signedOut = true
            dnsSession.signedIn = false
            await dnsSession.client?.signOut()
            try? KeychainSession(store: secretStore).deleteSessionID()
            apply(AdBlockerHome.failed(.needsSignIn, now: Date()))
        case .pauseAdBlocking, .resumeAdBlocking, .blockDomain, .allowDomain, .refresh:
            break
        }
        pending = nil
    }
}
