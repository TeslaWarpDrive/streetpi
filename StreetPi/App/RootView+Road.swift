import StreetPiCore
import SwiftUI

@Observable
@MainActor
final class CertificateRecovery {
    var reading = PiProbe.Reading(mode: .home)
    var gatewayReply = GatewayProbe.Reply.noAnswer
    var awayHTTP: AwayHTTPClient?
    var declinedPin: String?
    var dnsProblem: PiholeProblem?
    /// A clear away-live read has happened since the last probe or sign-out.
    var homeProbeYields = false
    var trigger = ConnectionTrigger.launch
    var retry = 0
    var generation = 0
}

/// Finding the road to the house, and the parts that only exist away from home.
extension RootView {
    func probeMode() async -> ConnectionMode? {
        await probeRoad(
            gateway: AwayGatewayStore(store: secretStore).active(),
            mailbox: MailboxSettingsStore(store: secretStore).load(),
            home: { await PiProbe().connection(gateway: nil, mailbox: nil) },
            gatewayReply: { await GatewayProbe().reply($0) }
        )
    }

    func probeRoad(
        gateway: AwayGatewaySettings?,
        mailbox: MailboxSetup?,
        home: () async -> PiProbe.Reading,
        gatewayReply: (AwayGatewaySettings) async -> GatewayProbe.Reply
    ) async -> ConnectionMode? {
        let generation = certificateRecovery.generation
        var reading = await home()
        var reply = GatewayProbe.Reply.noAnswer
        if reading.mode != .home {
            if let gateway { reply = await gatewayReply(gateway) }
            reading.mode = ConnectionMode.choose(
                piAnswered: false, gateway: gateway,
                gatewayAnswered: reply == .answered, mailbox: mailbox
            )
        }
        guard !Task.isCancelled, generation == certificateRecovery.generation else { return nil }
        certificateRecovery.gatewayReply = reply
        noteProbe(reading)
        return reading.mode
    }

    func probeMode(using probe: () async -> PiProbe.Reading) async -> ConnectionMode? {
        let generation = certificateRecovery.generation
        let reading = await probe()
        guard !Task.isCancelled, generation == certificateRecovery.generation else { return nil }
        noteProbe(reading)
        return reading.mode
    }

    var currentAccess: AdBlockerAccess {
        AdBlockerAccess(
            passwordSaved: passwordSaved,
            signedOut: signedOut,
            probePin: certificateRecovery.reading.presentedPin,
            readPin: presentedPin,
            declinedPin: certificateRecovery.declinedPin,
            dnsProblem: certificateRecovery.dnsProblem,
            road: mode,
            homeProbeYields: certificateRecovery.homeProbeYields
        )
    }

    func store(_ next: AdBlockerAccess) {
        passwordSaved = next.passwordSaved
        signedOut = next.signedOut
        presentedPin = next.readPin
        certificateRecovery.reading.presentedPin = next.probePin
        certificateRecovery.declinedPin = next.declinedPin
        certificateRecovery.dnsProblem = next.dnsProblem
        certificateRecovery.homeProbeYields = next.homeProbeYields
    }

    func noteProbe(_ reading: PiProbe.Reading) {
        certificateRecovery.reading = reading
        store(currentAccess.reduce(.probePresented(pin: reading.presentedPin)))
    }

    /// A session id belongs to one road, so a new road drops it and signs in again.
    func adopt(_ next: ConnectionMode) {
        guard next != mode else { return }
        mode = next
        let previous = dnsSession.client
        dnsSession.clear()
        // A read or probe still on the old road, away or at home, can no longer speak for the key.
        certificateRecovery.generation += 1
        certificateRecovery.awayHTTP = nil
        try? KeychainSession(store: secretStore).deleteSessionID()
        // The old road may be gone, so the app does not wait on this.
        Task { await previous?.signOut() }
    }

    /// One look after a failed request. The dwell runs out first, then a new answer restarts the watch.
    func reprobe() async {
        defer { dwell.reprobeFinished(now: Date()) }
        let left = dwell.secondsLeft(now: Date())
        if left > 0 {
            try? await Task.sleep(for: .seconds(left))
        }
        guard !Task.isCancelled else { return }
        guard let probed = await probeMode() else { return }
        guard !Task.isCancelled, probed != mode else { return }
        certificateRecovery.trigger = .requestFailed
        modeCheck += 1
    }

    func noteRead(worked: Bool) {
        if worked {
            dwell.requestSucceeded()
        } else if dwell.wantsReprobe(now: Date()) {
            reprobeAsk += 1
        }
    }

    var isAwayLive: Bool {
        if case .awayLive = mode { return true }
        return false
    }

    var liveRoad: LiveRoad {
        if case .awayLive(let gateway) = mode, let endpoints = LiveEndpoints.away(gateway) {
            return LiveRoad(endpoints: endpoints, sender: awayRoad.reader(for: gateway), isAway: true)
        }
        return LiveRoad(endpoints: LiveHostStore().load(), sender: liveClient, isAway: false)
    }

    func watchAway(_ setup: MailboxSetup) async {
        var failures = 0
        while !Task.isCancelled {
            guard await pullAway(setup) else { return }
            failures = awaySession.problem == nil ? 0 : failures + 1
            noteRead(worked: !mode.looksAgain(readFailed: awaySession.problem != nil, keyRejected: awayKeyRejected))
            try? await Task.sleep(for: .seconds(AwayPace.waitSeconds(afterFailures: failures)))
        }
    }

    /// False when the read was cancelled.
    func pullAway(_ setup: MailboxSetup) async -> Bool {
        let client = MailboxClient(transport: mailboxSession, setup: setup)
        guard let next = try? await awaySession.refreshed(using: client, now: Date()) else { return false }
        awaySession = next
        clock = Date()
        return true
    }

    /// No Keychain session here. The id stays in memory and dies with this road.
    func awayClient(_ gateway: AwayGatewaySettings) -> PiholeClient {
        if let existing = dnsSession.client, dnsSession.gateway == gateway, certificateRecovery.awayHTTP != nil {
            return existing
        }
        let store = secretStore
        let base = gateway.piholeBase ?? LiveEndpoints.house.pihole
        let http = AwayHTTPClient(settings: gateway, configuration: AwayHTTPClient.piholeConfiguration())
        certificateRecovery.awayHTTP = http
        let client = PiholeClient(
            transport: AwayPiholeTransport(base: LivePiholeTransport(http: http, base: base)),
            password: { AdBlockerSecrets.password(in: store) }
        )
        dnsSession.clear()
        dnsSession.client = client
        dnsSession.gateway = gateway
        return client
    }

    func loadGatewayForm() {
        let store = AwayGatewayStore(store: secretStore)
        gatewayAddress = store.addressText()
        gatewaySaved = store.load() != nil
        gatewayEnabled = store.enabled
    }

    var gatewayForm: AwayGatewayForm {
        makeGatewayForm(store: AwayGatewayStore(store: secretStore))
    }

    func makeGatewayForm(store: AwayGatewayStore) -> AwayGatewayForm {
        AwayGatewayForm(
            address: gatewayAddress,
            saved: gatewaySaved,
            enabled: gatewayEnabled,
            onSave: { address, clientID, secret in
                let result = store.save(address: address, clientID: clientID, secret: secret)
                if result == .saved { gatewayChanged() }
                return result
            },
            onRemove: {
                let result = store.remove()
                if result == .saved { gatewayChanged() }
                return result
            },
            onEnabled: { enabled in
                store.setEnabled(enabled)
                gatewayChanged()
            },
            savedStamp: { store.stamp }
        )
    }

    func gatewayChanged() {
        loadGatewayForm()
        certificateRecovery.generation += 1
        certificateRecovery.gatewayReply = .noAnswer
        certificateRecovery.awayHTTP = nil
        certificateRecovery.trigger = .settingsChanged
        modeCheck += 1
    }

    /// Runs on its own, so a long wait does not hold the other controls. Face ID already passed.
    func startAwayGravity() async {
        pending = nil
        guard awayGravity == nil else {
            actionNotice = ActionNotice(problem: .busy)
            return
        }
        guard let client = await preparedClient() else {
            actionNotice = ActionNotice(problem: .needsPassword)
            return
        }
        let flow = AwayGravityFlow(
            client: client,
            sleep: { try await Task.sleep(for: .seconds($0)) },
            onStep: { @MainActor step in actionNotice = step.notice }
        )
        awayGravity = Task {
            do {
                let receipt = try await flow.run()
                desk = desk.adopting(receipt)
                actionNotice = ActionNotice(receipt: receipt)
            } catch let problem as PiholeProblem {
                actionNotice = ActionNotice(problem: problem)
            } catch {
                actionNotice = ActionNotice(problem: .offline)
            }
            awayGravity = nil
        }
    }

    /// Reuses the open reader client, so the next action sends the same session id.
    func preparedClient() async -> PiholeClient? {
        if let client = dnsSession.client {
            return client
        }
        guard LiveReaderGate.opensSockets else { return nil }
        guard AdBlockerSecrets.password(in: secretStore).isEmpty == false else { return nil }
        return await clientForCurrentSettings()
    }
}

/// Shared by the Ad blocker board and Settings, including the mailbox fallback.
struct AwayKeyNotice: ViewModifier {
    var rejected: Bool
    var section: AppSection
    /// The away card says it instead, so a rejected key never stacks two cards above the page.
    var hasAwayCard = false

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var text: String? {
        guard rejected, section == .group(.adBlockerAndDNS) || section == .settings else { return nil }
        return AwayKeyProblem.rejected.message
    }

    /// Settings says it in the page, above the fields, so nothing fixed holds the way out off screen.
    var onPage: Bool {
        text != nil && section == .settings
    }

    func body(content: Content) -> some View {
        VStack(spacing: 0) {
            if let text, !hasAwayCard, !onPage {
                Label(text, systemImage: "key.slash")
                    .font(dynamicTypeSize.isAccessibilitySize ? .caption : .footnote)
                    .foregroundStyle(StreetTheme.house.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Rhythm.line)
                    .background(StreetTheme.house.surface)
            }
            content
        }
        .environment(\.awayKeyNotice, text)
        .environment(\.awayKeyOnPage, onPage)
        .environment(\.awayOnSettings, section == .settings)
    }
}
