import SwiftUI
import StreetPiCore

struct RootView: View {
    @State private var clock: Date
    @State private var screen = HouseScreen.ready(.healthyFixture)
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
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.secretStore) private var secretStore

    init(now: Date) {
        _clock = State(initialValue: now)
        let fixtures = FixtureGate.isFixtureRun
        _showLaunch = State(initialValue: !fixtures)
        if !fixtures {
            _screen = State(initialValue: .empty)
            _desk = State(initialValue: .quiet)
            _machine = State(initialValue: .quiet)
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
            onSetupCancel: { showsSetup = false }
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
            if FixtureGate.isFixtureRun {
                await watchHouse()
            } else {
                await watchLive()
            }
        }
        .task(id: dnsPage) {
            guard !FixtureGate.isFixtureRun, dnsPage == .liveLog, scenePhase == .active else { return }
            while !Task.isCancelled, dnsPage == .liveLog, scenePhase == .active {
                await refreshLiveLog()
                try? await Task.sleep(for: .seconds(4))
            }
        }
    }

    /// Fixture refresh for tests and previews.
    private func watchHouse() async {
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

    /// Charts, containers, alarms, the live log, and the upkeep text log. No fixtures.
    private func watchLive() async {
        var textFeed = TextLogFeed()
        var queryFeed = LiveLogFeed()
        let reader = NetdataReader { path in
            try await NetdataURLSessionTransport().get(pathAndQuery: path)
        }
        var failures = 0
        while !Task.isCancelled, scenePhase == .active {
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
        guard let client = prepareClient() else {
            let note = PiholeProblem.needsPassword.title
            return LogPull(queries: queryFeed, text: textFeed, liveNote: note, textNote: note)
        }
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
        guard let client = prepareClient() else {
            if desk.liveQueries.isEmpty {
                desk.liveReadNote = PiholeProblem.needsPassword.title
            }
            return
        }
        let pulled = await pullLive(client: client, feed: LiveLogFeed(queries: desk.liveFeed ?? []))
        desk.liveFeed = pulled.feed.queries
        desk.liveReadNote = pulled.feed.queries.isEmpty ? pulled.note : nil
    }

    private func prepareClient() -> PiholeClient? {
        if let client = dnsSession.client { return client }
        guard let stored = try? secretStore.load(for: AppPassword.account),
              let password = String(data: stored, encoding: .utf8),
              !password.isEmpty
        else { return nil }
        let endpoints = LiveHostStore().load()
        let client = PiholeClient(
            transport: LivePiholeTransport(client: LiveHTTPClient(), base: endpoints.pihole),
            password: { password }
        )
        dnsSession.client = client
        return client
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
