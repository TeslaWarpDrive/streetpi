import Foundation

public struct ServiceEndpoint: Sendable, Equatable, Codable {
    public var host: String
    public var port: Int
    public var useTLS: Bool

    public init(host: String, port: Int, useTLS: Bool) {
        self.host = host
        self.port = port
        self.useTLS = useTLS
    }
}

/// Service endpoints with hosts supplied at runtime. Tests and previews can use the fixture plan.
public struct ConnectionPlan: Sendable, Equatable, Codable {
    public var statusPage: ServiceEndpoint
    public var telemetry: ServiceEndpoint
    public var dns: ServiceEndpoint
    public var shell: ServiceEndpoint

    public init(
        statusPage: ServiceEndpoint,
        telemetry: ServiceEndpoint,
        dns: ServiceEndpoint,
        shell: ServiceEndpoint
    ) {
        self.statusPage = statusPage
        self.telemetry = telemetry
        self.dns = dns
        self.shell = shell
    }

    public static let fixture = ConnectionPlan(
        statusPage: ServiceEndpoint(host: "fixture.local", port: 3001, useTLS: false),
        telemetry: ServiceEndpoint(host: "fixture.local", port: 19999, useTLS: false),
        dns: ServiceEndpoint(host: "fixture.local", port: 80, useTLS: false),
        shell: ServiceEndpoint(host: "fixture.local", port: 22, useTLS: false)
    )

    public var endpoints: [ServiceEndpoint] {
        [statusPage, telemetry, dns, shell]
    }
}

public protocol StatusPageClient: Sendable {
    func services() async throws -> [ServiceHealth]
}

public protocol TelemetryClient: Sendable {
    func reading() async throws -> MachineReading
}

public protocol DNSClient: Sendable {
    func summary() async throws -> DNSSummary
}

public protocol LinkDetecting: Sendable {
    func currentLink() -> LinkState
}

public struct FixtureStatusPageClient: StatusPageClient {
    public var result: [ServiceHealth]

    public init(result: [ServiceHealth]) {
        self.result = result
    }

    public func services() async throws -> [ServiceHealth] {
        result
    }
}

public struct FixtureTelemetryClient: TelemetryClient {
    public var result: MachineReading

    public init(result: MachineReading) {
        self.result = result
    }

    public func reading() async throws -> MachineReading {
        result
    }
}

public struct FixtureDNSClient: DNSClient {
    public var result: DNSSummary

    public init(result: DNSSummary) {
        self.result = result
    }

    public func summary() async throws -> DNSSummary {
        result
    }
}

public struct FixtureLinkDetector: LinkDetecting {
    public var link: LinkState

    public init(link: LinkState) {
        self.link = link
    }

    public func currentLink() -> LinkState {
        link
    }
}

public struct HouseholdStatusLoader<
    StatusPage: StatusPageClient,
    Telemetry: TelemetryClient,
    DNS: DNSClient
>: Sendable {
    public var statusPage: StatusPage
    public var telemetry: Telemetry
    public var dns: DNS
    public var link: LinkState
    public var now: @Sendable () -> Date

    public init(
        statusPage: StatusPage,
        telemetry: Telemetry,
        dns: DNS,
        link: LinkState,
        now: @escaping @Sendable () -> Date
    ) {
        self.statusPage = statusPage
        self.telemetry = telemetry
        self.dns = dns
        self.link = link
        self.now = now
    }

    public func load() async throws -> HouseholdSnapshot {
        async let loadedServices = statusPage.services()
        async let loadedReading = telemetry.reading()
        async let loadedSummary = dns.summary()
        return try await HouseholdSnapshot(
            capturedAt: now(),
            link: link,
            services: loadedServices,
            machine: loadedReading,
            dns: loadedSummary
        )
    }
}

public extension HouseholdStatusLoader
where StatusPage == FixtureStatusPageClient,
      Telemetry == FixtureTelemetryClient,
      DNS == FixtureDNSClient {
    static func healthyFixture(now: @escaping @Sendable () -> Date = { .streetFixtureNow }) -> Self {
        let snapshot = HouseholdSnapshot.healthyFixture
        return Self(
            statusPage: FixtureStatusPageClient(result: snapshot.services),
            telemetry: FixtureTelemetryClient(result: snapshot.machine ?? MachineReading()),
            dns: FixtureDNSClient(result: snapshot.dns ?? DNSSummary(blockingEnabled: true)),
            link: snapshot.link,
            now: now
        )
    }
}
