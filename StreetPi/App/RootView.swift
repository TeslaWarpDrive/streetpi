import SwiftUI
import StreetPiCore

struct RootView: View {
    @State var clock: Date
    @State private var screen: HouseScreen
    @State private var section = AppSection.home
    @State var desk: DNSDesk
    @State private var dnsPage: DNSPage?
    @State private var machine: MachineDesk
    @State private var machinePage: MachinePage?
    @State var pending: HouseholdAction?
    @State var actionNotice: ActionNotice?
    @State private var sending = false
    @State private var passwordSaved = false
    @State private var showsSetup = false
    @State var dnsSession = DNSSessionHold()
    @State private var showLaunch: Bool
    @State private var presentedPin: String?
    @State var certificateRecovery = CertificateRecovery()
    @State private var signedOut = false
    @State private var piHost: String
    @State private var committedHost: String
    @State private var hostNote: String?
    @State private var piNotice: String?
    @State private var liveReading: MachineReading?
    @State var liveClient: LiveHTTPClient
    @State private var statusAddress: String
    @State private var statusSlug: String
    @State private var statusBoard: HouseStatusBoard?
    @State var mode: ConnectionMode
    @State var modeCheck = 0
    @State var dwell = ConnectionDwell()
    @State var reprobeAsk = 0
    @State var awayRoad = AwayRoadHold()
    @State var awayGravity: Task<Void, Never>?
    @State var gatewayAddress = ""
    @State var gatewaySaved = false
    @State var gatewayEnabled = true
    @State var awaySession = AwaySession()
    @State var mailboxSession = MailboxURLSession()
    @State private var mailboxAddress = ""
    @State private var mailboxTokenSaved = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.secretStore) var secretStore

    init(now: Date, mode: ConnectionMode = .home) {
        _mode = State(initialValue: mode)
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

    var displayedDNSProblem: PiholeProblem? {
        var reading = certificateRecovery.reading
        reading.mode = mode
        return reading.problem(declinedPin: certificateRecovery.declinedPin)
            ?? (awayBoard == nil ? certificateRecovery.dnsProblem : nil)
    }

    func trustPresentedPin(hosts: LiveHostStore = LiveHostStore()) {
        guard let presentedPin = certificateRecovery.reading.presentedPin ?? presentedPin,
              PiholePin.isSHA256Pin(presentedPin) else { return }
        do {
            try hosts.savePin(presentedPin)
        } catch {
            return
        }
        dnsSession.http?.apply(hosts)
        liveClient.apply(hosts)
        certificateRecovery.declinedPin = nil
        self.presentedPin = nil
        certificateRecovery.generation += 1
        certificateRecovery.reading.presentedPin = nil
        signedOut = false
        certificateRecovery.trigger = .settingsChanged
        certificateRecovery.retry += 1
    }

    func keepSavedPin() {
        certificateRecovery.declinedPin = certificateRecovery.reading.presentedPin
            ?? presentedPin ?? certificateRecovery.declinedPin
        switch mode {
        case .awayLive, .awayMailbox:
            if certificateRecovery.dnsProblem == .certificateChanged || certificateRecovery.dnsProblem == .pinKept {
                certificateRecovery.dnsProblem = nil
            }
        case .home, .offline: apply(AdBlockerHome.failed(.pinKept, now: Date()))
        }
    }

    var body: some View {
        let away = awayBoard
        AppShell(
            section: section,
            screen: away.map(awayScreen) ?? screen,
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
            desk: away?.desk ?? desk,
            dnsPage: dnsPage,
            machine: away?.machine ?? machine,
            machinePage: machinePage,
            pendingAction: pending,
            actionNotice: actionNotice,
            passwordSaved: passwordSaved,
            showsSetup: showsSetup,
            dnsProblem: displayedDNSProblem,
            sessionActive: dnsSession.signedIn,
            trustNote: setupTrustNote,
            offersSetup: !passwordSaved,
            onTrustNewCertificate: { trustPresentedPin() },
            onKeepSavedPin: keepSavedPin,
            onSettingsSaved: {
                signedOut = false
                certificateRecovery.retry += 1
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
            piNotice: away == nil ? piNotice : away?.piNotice,
            machineReading: away == nil ? liveReading : away?.snapshot?.machine,
            statusBoard: away == nil ? statusBoard : away?.status,
            statusAddress: statusAddress,
            statusSlug: statusSlug,
            onStatusPage: saveStatusPage,
            awayStatus: awayStatus,
            mailboxAddress: mailboxAddress,
            mailboxTokenSaved: mailboxTokenSaved,
            onSaveMailbox: saveMailbox,
            onRemoveMailbox: removeMailbox,
            awayLive: isAwayLive,
            gatewayForm: gatewayForm
        )
        .modifier(AwayKeyNotice(rejected: awayKeyRejected, section: section, hasAwayCard: awayStatus != nil))
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
            if !LiveGate.usesFixtures {
                MailboxSettingsStore(store: secretStore).seedIfNeeded(from: .bundled())
                AwayGatewayStore(store: secretStore).seedIfNeeded(from: .bundled())
            }
            loadMailboxForm()
            loadGatewayForm()
            if LiveGate.usesFixtures {
                await watchFixtures()
            } else {
                await watchLive()
            }
        }
        .task {
            guard !LiveGate.usesFixtures else { return }
            for await _ in NetworkPathChanges.stream() {
                certificateRecovery.trigger = .pathChanged
                modeCheck += 1
            }
        }
        .task(id: reprobeAsk) {
            guard reprobeAsk > 0 else { return }
            await reprobe()
        }
        .task(id: "\(String(describing: dnsPage))|\(modeCheck)") {
            guard !LiveGate.usesFixtures, dnsPage == .liveLog, scenePhase == .active, awayBoard == nil else { return }
            while !Task.isCancelled, dnsPage == .liveLog, scenePhase == .active, signedOut == false {
                await refreshLiveLog()
                try? await Task.sleep(for: .seconds(4))
            }
        }
    }

    private var watchToken: String {
        "\(scenePhase)|\(committedHost)|\(certificateRecovery.retry)|\(signedOut)|\(statusAddress)|\(statusSlug)|\(modeCheck)"
    }

    /// Nil at home. Away, the screens read this and the home state waits untouched.
    private var awayBoard: AwayBoard? {
        guard case .awayMailbox = mode else { return nil }
        return awaySession.board
    }

    private var awayStatus: AwayStatus? {
        switch mode {
        case .home, .awayLive:
            nil
        case .offline:
            gatewaySaved && gatewayEnabled ? .unreachable : .notSetUp
        case .awayMailbox:
            awaySession.status
        }
    }

    private func awayScreen(_ board: AwayBoard) -> HouseScreen {
        guard let snapshot = board.snapshot, let status = board.status else {
            return .explained(
                PlainEnglishStatus(
                    headline: HouseReadingCopy.lookingTitle,
                    detail: HouseReadingCopy.emptyDetail,
                    tone: .calm,
                    linkLine: "Away"
                ),
                nil
            )
        }
        var briefing = status.briefing
        briefing.linkLine = "Away"
        return .explained(briefing, snapshot)
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
        guard let probed = await probeMode(), !Task.isCancelled else { return }
        let trigger = certificateRecovery.trigger
        certificateRecovery.trigger = .foreground
        adopt(dwell.settle(probed, trigger: trigger, now: Date()))
        if case .awayMailbox(let setup) = mode {
            await watchAway(setup)
            return
        }
        async let house: Void = watchHouse()
        async let status: Void = pumpStatus()
        async let meters: Void = pumpMeters()
        async let history: Void = pumpHistory()
        _ = await (house, status, meters, history)
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
            if mode.looksAgain(readFailed: board.problem == .offline, keyRejected: awayKeyRejected) {
                noteRead(worked: false)
            }
            let wait = RefreshPace.waitSeconds(afterFailures: failures)
            try? await Task.sleep(for: .seconds(wait))
        }
    }

    /// A pull looks for the Pi again. A new answer restarts the watch on the right road.
    private func refreshNow() async {
        guard LiveReaderGate.opensSockets else { return }
        guard let next = await probeMode() else { return }
        guard next == mode else {
            certificateRecovery.trigger = .manual
            modeCheck += 1
            return
        }
        if case .awayMailbox(let setup) = next {
            _ = await pullAway(setup)
            return
        }
        guard signedOut == false else { return }
        let client = await clientForCurrentSettings()
        apply(await refresh(client, now: Date()))
    }

    func clientForCurrentSettings() async -> PiholeClient {
        if case .awayLive(let gateway) = mode {
            return awayClient(gateway)
        }
        let hosts = LiveHostStore()
        let endpoint = PiholeBaseAddress.endpoint(from: hosts.piholeText()) ?? .house
        let pin = hosts.pinText()
        if let existing = dnsSession.client, dnsSession.endpoint == endpoint, dnsSession.pin == pin {
            dnsSession.http?.apply(hosts)
            liveClient.apply(hosts)
            return existing
        }
        let previous = dnsSession.client
        let configuration = LiveHTTPClient.sessionConfiguration()
        configuration.timeoutIntervalForRequest = 300
        configuration.timeoutIntervalForResource = 300
        let http = LiveHTTPClient(store: hosts, configuration: configuration)
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

    var awayKeyRejected: Bool {
        certificateRecovery.gatewayReply == .rejectedKey
    }

    func refresh(
        _ client: PiholeClient, now: Date, secrets: (any SecretStoring)? = nil
    ) async -> AdBlockerBoard {
        let generation = certificateRecovery.generation
        let http = isAwayLive ? certificateRecovery.awayHTTP : nil
        _ = http?.takeKeyRejection()
        let saved = AdBlockerSecrets.password(in: secrets ?? secretStore).isEmpty == false
        var piAnswered = false
        let board = await readBoard(client, now: now, saved: saved, piAnswered: &piAnswered)
        guard !Task.isCancelled, generation == certificateRecovery.generation else { return board }
        if let http {
            guard http === certificateRecovery.awayHTTP else { return board }
            if http.takeKeyRejection() {
                certificateRecovery.gatewayReply = .rejectedKey
                return AdBlockerHome.offline(now: now)
            }
        }
        // Pi-hole itself replied, so no key is in doubt, whatever the board goes on to say.
        if piAnswered {
            certificateRecovery.gatewayReply = http == nil ? .noAnswer : .answered
        }
        return board
    }

    private func readBoard(
        _ client: PiholeClient, now: Date, saved: Bool, piAnswered: inout Bool
    ) async -> AdBlockerBoard {
        do {
            let state = try await client.reachability()
            piAnswered = true
            guard saved else { return AdBlockerHome.notSetUp(now: now) }
            if state == .dnsOff { return AdBlockerHome.dnsOff(now: now) }
            let load = try await client.loadDesk(now: now)
            dnsSession.signedIn = true
            return AdBlockerHome.ready(load, now: now)
        } catch let problem as PiholeProblem {
            dnsSession.signedIn = false
            if problem == .certificateChanged {
                let presented = dnsSession.presented?.presented()
                if let presented, presented == certificateRecovery.declinedPin {
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
        } catch AwayKeyProblem.rejected {
            // Only the away road has a key. At home this stays a service that is not set up.
            dnsSession.signedIn = false
            return isAwayLive ? AdBlockerHome.offline(now: now) : AdBlockerHome.notSetUp(now: now)
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
        var status = board.status
        if isAwayLive {
            status.linkLine = AwayCopy.awayChip
        }
        screen = .explained(status, snapshot)
        certificateRecovery.dnsProblem = board.problem
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

    func readStatusPage() async throws -> StatusPageLoad {
        let road = liveRoad
        let address = road.isAway ? road.endpoints.uptimeKuma.absoluteString : statusAddress
        let slug = road.isAway ? AwayGatewaySettings.statusSlug : statusSlug
        guard let base = LiveAddress.validated(address, schemes: ["http", "https"]),
              let endpoint = StatusPageEndpoint.make(base: base, slug: slug)
        else { throw StatusPageProblem.notUnderstood }
        let transport = StatusPageLiveTransport(sender: road.sender, base: base)
        let reader = StatusPageReader(transport: transport, endpoint: endpoint, now: { Date() })
        return try await reader.load()
    }

    private func saveSetup(_ raw: String) {
        guard raw.isEmpty == false else { return }
        do {
            try KeychainSession(store: secretStore).saveAppPassword(raw)
            passwordSaved = true
            showsSetup = false
            signedOut = false
            certificateRecovery.retry += 1
        } catch {
            showsSetup = true
        }
    }

    func loadMailboxForm() {
        let store = MailboxSettingsStore(store: secretStore)
        mailboxAddress = store.addressText()
        mailboxTokenSaved = store.tokenSaved()
    }

    func saveMailbox(address: String, token: String) -> MailboxSaveResult {
        let result = MailboxSettingsStore(store: secretStore).save(address: address, token: token)
        if result == .saved {
            loadMailboxForm()
            modeCheck += 1
        }
        return result
    }

    func removeMailbox() -> MailboxSaveResult {
        let result = MailboxSettingsStore(store: secretStore).remove()
        if result == .saved {
            loadMailboxForm()
            awaySession = AwaySession()
            modeCheck += 1
        }
        return result
    }

    private func confirm(_ action: HouseholdAction) async {
        guard !sending else { return }
        if mode.allows(action) == false {
            actionNotice = ActionNotice(
                title: AwayCopy.onlyAtHomeTitle,
                detail: AwayCopy.onlyAtHomeDetail,
                failed: false
            )
            pending = nil
            return
        }
        sending = true
        defer { sending = false }
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
            actionNotice = nil
            apply(AdBlockerHome.failed(.needsSignIn, now: Date()))
            pending = nil
        case .refresh:
            pending = nil
            await refreshNow()
        default:
            guard PiholeActionRoute.callsTheAPI(action) else {
                pending = nil
                return
            }
            if action == .updateBlockLists, isAwayLive {
                await startAwayGravity()
            } else {
                await performLive(action)
            }
        }
    }

    /// Production calls Pi-hole and shows that answer. It does not edit the fixture desk.
    private func performLive(_ action: HouseholdAction) async {
        guard let client = await preparedClient() else {
            actionNotice = ActionNotice(problem: .needsPassword)
            pending = nil
            return
        }
        do {
            let receipt = try await PiholeActions.perform(action, client: client, now: Date())
            desk = desk.adopting(receipt)
            actionNotice = ActionNotice(receipt: receipt)
        } catch let problem as PiholeProblem {
            actionNotice = ActionNotice(problem: problem)
        } catch {
            actionNotice = ActionNotice(problem: .offline)
        }
        pending = nil
    }

    func saveStatusPage(address: String, slug: String) {
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

    private func pumpMeters() async {
        var failures = 0
        while !Task.isCancelled {
            let road = liveRoad
            let refresh = PiMeterRefresh(client: road.sender, base: road.endpoints.netdata, isAway: road.isAway)
            guard let result = await refresh.load() else { return }
            if Task.isCancelled { return }
            switch result {
            case .success(let meters):
                apply(meters)
                failures = meters.reading.hasSignal ? 0 : failures + 1
                noteRead(worked: true)
            case .failure(let problem):
                liveReading = nil
                piNotice = problem.sentence
                failures += 1
                noteRead(worked: false)
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
            let road = liveRoad
            let reader = NetdataHistoryReader(
                transport: NetdataLiveTransport(client: road.sender, base: road.endpoints.netdata, isAway: road.isAway),
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

    private func pullLogs(textFeed: TextLogFeed, queryFeed: LiveLogFeed) async -> LogPull {
        guard signedOut == false, LiveReaderGate.opensSockets else {
            let note = PiholeProblem.needsSignIn.title
            return LogPull(queries: queryFeed, text: textFeed, liveNote: note, textNote: note)
        }
        let client = await clientForCurrentSettings()
        return await LogPull.both(client: client, textFeed: textFeed, queryFeed: queryFeed)
    }

    private func refreshLiveLog() async {
        guard signedOut == false else { return }
        let client = await clientForCurrentSettings()
        let pulled = await LogPull.live(client: client, feed: LiveLogFeed(queries: desk.liveFeed ?? []))
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

    private static func houseCharts(_ text: String) -> URL? {
        guard let url = LiveAddress.validated(text, schemes: ["http", "https"]),
              let host = url.host?.lowercased(),
              !host.contains("netdata.cloud"),
              !host.contains("my-netdata.io")
        else { return nil }
        return url
    }

}
