import Foundation
import StreetPiCore

/// One quick look for the Pi on the home network.
/// Any reply from the ad blocker counts, because the pinned certificate already proved who it is.
struct PiProbe: Sendable {
    private static let timeout: TimeInterval = 1.5

    private let http: LiveHTTPClient
    private let hosts: LiveHostStore

    init(hosts: LiveHostStore = LiveHostStore()) {
        self.hosts = hosts
        let configuration = LiveHTTPClient.sessionConfiguration()
        configuration.timeoutIntervalForRequest = Self.timeout
        configuration.timeoutIntervalForResource = Self.timeout
        http = LiveHTTPClient(store: hosts, configuration: configuration)
    }

    func connection(
        gateway: AwayGatewaySettings?,
        mailbox: MailboxSetup?
    ) async -> Reading {
        guard LiveReaderGate.opensSockets else { return Reading(mode: .offline) }
        let presented = PresentedPinBox()
        let transport = PiholeURLSessionTransport(
            http: http,
            endpoint: PiholeBaseAddress.endpoint(from: hosts.piholeText()) ?? .house,
            sessions: KeychainSession(store: KeychainSecretStore()),
            presented: presented
        )
        return await Self.connection(
            transport: transport, presented: presented, gateway: gateway, mailbox: mailbox,
            gatewayAnswers: { await GatewayProbe().answers($0) }
        )
    }

    struct Reading: Sendable, Equatable {
        var mode: ConnectionMode
        var presentedPin: String?

        func problem(declinedPin: String?) -> PiholeProblem? {
            guard let presentedPin else { return nil }
            return presentedPin == declinedPin ? .pinKept : .certificateChanged
        }
    }

    /// Certificate recovery only captures a fingerprint. It never authenticates a LAN request.
    static func connection(
        transport: any PiholeTransport,
        presented: PresentedPinBox,
        gateway: AwayGatewaySettings?,
        mailbox: MailboxSetup?,
        gatewayAnswers: @escaping @Sendable (AwayGatewaySettings) async -> Bool
    ) async -> Reading {
        var changedPin: String?
        do {
            _ = try await transport.send(PiholeRequest(
                method: "GET", path: "/api/info/login", headers: [:], body: nil
            ))
            return Reading(mode: .home)
        } catch PiholeProblem.certificateChanged {
            changedPin = presented.presented()
        } catch {
            // A failed pin never proves home, even when another service answers.
        }
        let prober = ConnectionProber(piAnswers: { false }, gatewayAnswers: gatewayAnswers)
        let mode = await prober.mode(gateway: gateway, mailbox: mailbox)
        return Reading(mode: mode, presentedPin: changedPin)
    }

    /// Only contact through the pinned Pi-hole client proves home. Plaintext charts cannot.
    static func pinnedPiAnswers(http: any LiveHTTPSending, base: URL) async -> Bool {
        guard let url = LivePaths.url(base: base, path: "/info/login") else { return false }
        return (try? await http.get(url, headers: ["Accept": "application/json"])) != nil
    }
}
