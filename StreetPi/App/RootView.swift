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
    @State private var piHost: String
    @State private var committedHost: String
    @State private var hostNote: String?
    @State private var piNotice: String?
    @State private var liveReading: MachineReading?
    @State private var liveClient: LiveHTTPClient
    @State private var statusAddress: String
    @State private var statusSlug: String
    @State private var statusBoard: HouseStatusBoard?
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
        _statusAddress = State(initialValue: store.uptimeKumaText())
        _statusSlug = State(initialValue: StatusPageSlugStore.current())
        _statusBoard = State(initialValue: nil)
        if fixtures {
            _screen = State(initialValue: .ready(.healthyFixture))
            _desk = State(initialValue: .houseFixture)
            _machine = State(initialValue: .houseFixture)
            _piNotice = State(initialValue: nil)
            _liveReading = State(initialValue: HouseholdSnapshot.healthyFixture.machine)
        } else {
            let looking = PlainEnglishStatus(
                headline: HouseReadingCopy.lookingTitle,
                detail: HouseReadingCopy.emptyDetail,
                tone: .calm,
                linkLine: "On the home network"
            )
            _screen = State(initialValue: .explained(looking, nil))
            _desk = State(initialValue: .quiet)
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
            onRefresh: refreshNow,
            piHost: $piHost,
            hostNote: hostNote,
            onCommitHost: commitPiHost,
            piNotice: piNotice,
            machineReading: liveReading,
            statusBoard: statusBoard,
            statusAddress: statusAddress,
            statusSlug: statusSlug,
            onStatusPage: saveStatusPage
        )
        .launchOverlay(isPresented: $showLaunch)
        .preferredColorScheme(.dark)
        .environment(\.secretStore, KeychainSecretStore())
        .onChange(of: scenePhase) { _, phase in
            guard phase == .background else { return }
            let client = dnsSession.client
            dnsSession.signedIn = false
            Task { await client?.appDidEnterBackground() }
        }
        .task(id: watchToken) {
            guard scenePhase == .active else { return }
            passwordSaved = (try? KeychainSession(store: secretStore).hasAppPassword()) ?? false
            if LiveGate.usesFixtures {
                await watchFixtures()
            } else {
                await watchLive()
            }
        }
        .task(id: dnsPage) {
            guard !LiveGate.usesFixtures, dnsPage == .liveLog, scenePhase == .active else { return }
            while !Task.isCancelled, dnsPage == .liveLog, scenePhase == .active, signedOut == false {
                await refreshLiveLog()
                try? await Task.sleep(for: .seconds(4))
            }
        }
    }

    private var watchToken: String {
        "\(scenePhase)|\(committedHost)|\(retry)|\(signedOut)|\(statusAddress)|\(statusSlug)"
    }

    private var setupTrustNote: String {
        "This phone checks the ad blocker's security pin from Settings. The pin stays on this phone."
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
        async let blocker: Void = watchHouse()
        async let status: Void = pumpStatus()
        async let meters: Void = pumpMeters()
        async let history: Void = pumpHistory()
        _ = await (blocker, status, meters, history)
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
            liveClient.apply(hosts)
            return existing
        }
        let previous = dnsSession.client
        let http = LiveHTTPClient(store: hosts)
        http.apply(hosts)
        liveClient.apply(hosts)
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
        dnsSession.client = client
        dnsSession.http = http
        dnsSession.endpoint = endpoint
        dnsSession.pin = pin
        dnsSession.presented = box
        dnsSession.signedIn = false
        if let previous {
            await previous.signOut()
        }
        if let saved = try? sessions.loadSessionID() {
            await client.restoreSession(
                id: saved,
                expiresAt: Date().addingTimeInterval(TimeInterval(FTLSessionPolicy.validitySeconds))
            )
        }
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
        desk = keepingLog(board.desk)
        var snapshot = board.snapshot
        snapshot.machine = liveReading
        screen = .explained(board.status, snapshot)
        dnsProblem = board.problem
        if board.problem != .certificateChanged {
            presentedPin = nil
        }
    }

    private func keepingLog(_ next: DNSDesk) -> DNSDesk {
        var merged = next
        merged.liveFeed = desk.liveFeed
        merged.liveReadNote = desk.liveReadNote
        merged.textLogLines = desk.textLogLines
        merged.textLogKnown = desk.textLogKnown
        merged.textLogReadNote = desk.textLogReadNote
        if desk.textLogKnown {
            merged.textLogFileEnabled = desk.textLogFileEnabled
        }
        return merged
    }
}

private extension RootView {
    /// The house tiles come from the status page. A miss does not invent fixture monitors.
    func pumpStatus() async {
        var failures = 0
        while !Task.isCancelled {
            do {
                let load = try await readStatusPage()
                statusBoard = load.board
                failures = 0
            } catch is CancellationError {
                return
            } catch {
                failures += 1
            }
            let wait = RefreshPace.waitSeconds(afterFailures: failures)
            try? await Task.sleep(for: .seconds(wait))
        }
    }

    private func readStatusPage() async throws -> StatusPageLoad {
        guard let base = LiveAddress.validated(statusAddress, schemes: ["http", "https"]),
              let endpoint = StatusPageEndpoint.make(base: base, slug: statusSlug)
        else { throw StatusPageProblem.notUnderstood }
        let transport = StatusPageLiveTransport(sender: liveClient, base: base)
        let reader = StatusPageReader(transport: transport, endpoint: endpoint, now: { Date() })
        return try await reader.load()
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
            showMachine()
            let wait = RefreshPace.waitSeconds(afterFailures: failures)
            try? await Task.sleep(for: .seconds(wait))
        }
    }

    /// Charts, containers, alarms, the live log, and the upkeep text log.
    private func pumpHistory() async {
        var textFeed = TextLogFeed()
        var queryFeed = LiveLogFeed()
        var failures = 0
        while !Task.isCancelled {
            let base = LiveHostStore().load().netdata
            let reader = NetdataHistoryReader(
                transport: NetdataLiveTransport(client: liveClient, base: base),
                now: { Date() }
            )
            let history = await reader.load()
            let log = await pullLogs(textFeed: textFeed, queryFeed: queryFeed)
            textFeed = log.text
            queryFeed = log.queries
            applyLive(history: history, log: log)
            let missed = history.chartNote != nil || log.liveNote != nil
            failures = missed ? failures + 1 : 0
            let wait = RefreshPace.waitSeconds(afterFailures: failures)
            try? await Task.sleep(for: .seconds(wait))
        }
    }

    private struct LogPull {
        var queries: LiveLogFeed
        var text: TextLogFeed
        var liveNote: String?
        var textNote: String?
    }

    private func pullLogs(textFeed: TextLogFeed, queryFeed: LiveLogFeed) async -> LogPull {
        guard signedOut == false, LiveReaderGate.opensSockets else {
            let note = PiholeProblem.needsSignIn.title
            return LogPull(queries: queryFeed, text: textFeed, liveNote: note, textNote: note)
        }
        let client = await clientForCurrentSettings()
        async let live = pullLive(client: client, feed: queryFeed)
        async let text = pullText(client: client, feed: textFeed)
        let liveResult = await live
        let textResult = await text
        return LogPull(
            queries: liveResult.feed,
            text: textResult.feed,
            liveNote: liveResult.note,
            textNote: textResult.note
        )
    }

    private func pullLive(
        client: PiholeClient,
        feed: LiveLogFeed
    ) async -> (feed: LiveLogFeed, note: String?) {
        do {
            let rows = try await client.liveQueries()
            return (feed.applying(rows), nil)
        } catch let problem as PiholeProblem {
            return (feed, LiveReadCopy.pihole(problem, fallback: LiveReadCopy.liveLog))
        } catch {
            return (feed, LiveReadCopy.offline)
        }
    }

    private func pullText(
        client: PiholeClient,
        feed: TextLogFeed
    ) async -> (feed: TextLogFeed, note: String?) {
        do {
            let page = try await client.textLog(after: feed.nextID)
            return (feed.applying(page), nil)
        } catch let problem as PiholeProblem {
            return (feed, LiveReadCopy.pihole(problem, fallback: LiveReadCopy.textLog))
        } catch {
            return (feed, LiveReadCopy.offline)
        }
    }

    private func refreshLiveLog() async {
        guard signedOut == false else { return }
        let client = await clientForCurrentSettings()
        let pulled = await pullLive(client: client, feed: LiveLogFeed(queries: desk.liveFeed ?? []))
        desk.liveFeed = pulled.feed.queries
        desk.liveReadNote = pulled.feed.queries.isEmpty ? pulled.note : nil
    }

    private func applyLive(history: NetdataHistoryLoad, log: LogPull) {
        if history.chartNote == nil {
            machine.series = history.series
        }
        machine.chartNote = history.chartNote
        if history.containerNote == nil {
            machine.containers = history.containers
        }
        machine.containerNote = history.containerNote
        if history.alertNote == nil {
            machine.alerts = history.alerts
        }
        machine.alertNote = history.alertNote
        let merged = LiveLogFeed(queries: desk.liveFeed ?? []).applying(log.queries.queries)
        desk.liveFeed = merged.queries
        desk.liveReadNote = merged.queries.isEmpty ? log.liveNote : nil
        desk.textLogLines = log.text.lines
        if log.textNote == nil {
            desk.textLogFileEnabled = log.text.fileEnabled
            desk.textLogKnown = true
            desk.textLogReadNote = nil
        } else {
            desk.textLogReadNote = log.textNote
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

    private func showMachine() {
        guard var snapshot = screen.snapshot else { return }
        snapshot.machine = liveReading
        snapshot.capturedAt = Date()
        clock = Date()
        if case .explained(let status, _) = screen {
            screen = .explained(status, snapshot)
        }
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
        dnsSession.http?.apply(store)
        hostNote = nil
        piHost = store.netdataText()
        committedHost = piHost
    }

    private func saveStatusPage(address: String, slug: String) {
        let store = LiveHostStore()
        guard let url = LiveAddress.validated(address, schemes: ["http", "https"]),
              StatusPageEndpoint.isSlug(slug)
        else { return }
        let current = store.load()
        do {
            try store.save(
                pihole: current.pihole.absoluteString,
                netdata: current.netdata.absoluteString,
                uptimeKuma: url.absoluteString
            )
        } catch {
            return
        }
        StatusPageSlugStore.save(slug)
        liveClient.apply(store)
        statusAddress = store.uptimeKumaText()
        statusSlug = StatusPageSlugStore.current()
    }

    private static func houseCharts(_ text: String) -> URL? {
        guard let url = LiveAddress.validated(text, schemes: ["http", "https"]),
              let host = url.host?.lowercased(),
              !host.contains("netdata.cloud"),
              !host.contains("my-netdata.io")
        else { return nil }
        return url
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
        liveClient.apply(hosts)
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
