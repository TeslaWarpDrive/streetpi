import Foundation

public struct DNSDesk: Sendable, Equatable, Codable {
    public var textLogFileEnabled: Bool
    public var blocking: DNSBlocking
    public var day: [DayChartSample]
    public var knownClients: Int
    public var listCount: Int
    public var listsUpdatedAt: Date
    public var clients: [NamedRow]
    public var clientsNote: String?
    public var groups: [NamedRow]
    public var domains: [NamedRow]
    public var lists: [DNSListRow]
    public var hosts: [NamedRow]
    public var cnames: [NamedRow]
    public var services: [DNSServiceChoice]
    public var queries: [DNSQuery]
    public var topDomains: [DNSCount]
    public var topClients: [DNSCount]
    public var blockedDomains: [DNSCount]
    /// Live sentence for the hub and Today. Fixtures leave this empty and keep the fixed line.
    public var spokenLine: String?
    /// False when the Pi did not report when the block lists last updated.
    public var listsUpdateKnown: Bool
    /// Live upkeep sentence. Fixtures leave this empty and keep the fixed note.
    public var upkeepNote: String?
    /// Set by the live poll. Nil keeps the sample prefix used by fixtures and snapshots.
    public var liveFeed: [DNSQuery]?
    public var textLogLines: [String]
    public var textLogKnown: Bool
    public var liveReadNote: String?
    public var textLogReadNote: String?

    public init(
        textLogFileEnabled: Bool,
        blocking: DNSBlocking,
        day: [DayChartSample],
        knownClients: Int,
        listCount: Int,
        listsUpdatedAt: Date,
        clients: [NamedRow],
        groups: [NamedRow],
        domains: [NamedRow],
        lists: [DNSListRow],
        hosts: [NamedRow],
        cnames: [NamedRow],
        services: [DNSServiceChoice],
        queries: [DNSQuery],
        topDomains: [DNSCount],
        topClients: [DNSCount],
        blockedDomains: [DNSCount],
        spokenLine: String? = nil,
        listsUpdateKnown: Bool = true,
        upkeepNote: String? = nil,
        liveFeed: [DNSQuery]? = nil,
        textLogLines: [String] = [],
        textLogKnown: Bool = true,
        liveReadNote: String? = nil,
        textLogReadNote: String? = nil,
        clientsNote: String? = nil
    ) {
        self.textLogFileEnabled = textLogFileEnabled
        self.blocking = blocking
        self.day = day
        self.knownClients = knownClients
        self.listCount = listCount
        self.listsUpdatedAt = listsUpdatedAt
        self.clients = clients
        self.clientsNote = clientsNote
        self.groups = groups
        self.domains = domains
        self.lists = lists
        self.hosts = hosts
        self.cnames = cnames
        self.services = services
        self.queries = queries
        self.topDomains = topDomains
        self.topClients = topClients
        self.blockedDomains = blockedDomains
        self.spokenLine = spokenLine
        self.listsUpdateKnown = listsUpdateKnown
        self.upkeepNote = upkeepNote
        self.liveFeed = liveFeed
        self.textLogLines = textLogLines
        self.textLogKnown = textLogKnown
        self.liveReadNote = liveReadNote
        self.textLogReadNote = textLogReadNote
    }

    public var queriesToday: Int {
        day.reduce(0) { $0 + $1.allowed + $1.blocked }
    }

    public var blockedToday: Int {
        day.reduce(0) { $0 + $1.blocked }
    }

    public var hasDayLookups: Bool {
        day.contains { $0.allowed + $0.blocked > 0 }
    }

    public var liveQueries: [DNSQuery] {
        if let liveFeed {
            return liveFeed
        }
        return Array(queries.prefix(3))
    }
}

extension DNSDesk {
    public static let houseFixture: DNSDesk = {
        let now = Date.streetFixtureNow
        let allowed = [
            12, 8, 6, 5, 7, 18, 42, 74, 96, 88, 71, 64,
            83, 76, 69, 81, 102, 128, 146, 154, 133, 97, 58, 26,
        ]
        let blocked = [
            3, 2, 1, 1, 2, 4, 11, 19, 24, 21, 16, 14,
            20, 18, 15, 19, 26, 33, 38, 41, 34, 24, 13, 6,
        ]
        let day = (0..<24).map { hour in
            DayChartSample(hour: hour, allowed: allowed[hour], blocked: blocked[hour])
        }
        return DNSDesk(
            textLogFileEnabled: false,
            blocking: DNSBlocking(enabled: true),
            day: day,
            knownClients: 4,
            listCount: 2,
            listsUpdatedAt: now.addingTimeInterval(-2 * 86_400),
            clients: [
                NamedRow(id: "192.0.2.20", name: "Living room", detail: "192.0.2.20 · 90 lookups"),
                NamedRow(id: "192.0.2.21", name: "Kitchen display", detail: "192.0.2.21 · 48 lookups"),
                NamedRow(id: "192.0.2.22", name: "Office laptop", detail: "192.0.2.22 · 35 lookups"),
                NamedRow(id: "192.0.2.23", name: "Upstairs speaker", detail: "192.0.2.23 · 12 lookups"),
            ],
            groups: [
                NamedRow(id: "default", name: "Default", detail: "4 devices"),
                NamedRow(id: "guests", name: "Guests", detail: "No devices yet"),
            ],
            domains: [
                NamedRow(id: "ads", name: "ads.example.test", detail: "Blocked"),
                NamedRow(id: "news", name: "news.example.test", detail: "Allowed"),
            ],
            lists: [
                DNSListRow(id: "block", name: "House block list", host: "fixture.local", enabled: true),
                DNSListRow(id: "allow", name: "House allow list", host: "fixture.local", enabled: true),
            ],
            hosts: [
                NamedRow(id: "printer", name: "printer.fixture.local", detail: "Inside the house"),
            ],
            cnames: [
                NamedRow(id: "camera", name: "camera.fixture.local", detail: "printer.fixture.local"),
            ],
            services: [
                DNSServiceChoice(
                    id: "video-ads",
                    name: "Video ads",
                    detail: "Clips that play before a show",
                    blocked: true
                ),
                DNSServiceChoice(
                    id: "trackers",
                    name: "Trackers",
                    detail: "Sites that follow a device around",
                    blocked: true
                ),
                DNSServiceChoice(
                    id: "shopping-ads",
                    name: "Shopping ads",
                    detail: "Offers from shops",
                    blocked: false
                ),
            ],
            queries: [
                DNSQuery(
                    id: "q1",
                    domain: "ads.example.test",
                    client: "Living room",
                    outcome: .blocked,
                    at: now.addingTimeInterval(-120)
                ),
                DNSQuery(
                    id: "q2",
                    domain: "news.example.test",
                    client: "Kitchen display",
                    outcome: .allowed,
                    at: now.addingTimeInterval(-80)
                ),
                DNSQuery(
                    id: "q3",
                    domain: "updates.example.test",
                    client: "Office laptop",
                    outcome: .allowed,
                    at: now.addingTimeInterval(-45)
                ),
                DNSQuery(
                    id: "q4",
                    domain: "tracker.example.test",
                    client: "Upstairs speaker",
                    outcome: .blocked,
                    at: now.addingTimeInterval(-20)
                ),
            ],
            topDomains: [
                DNSCount(name: "ads.example.test", count: 420),
                DNSCount(name: "news.example.test", count: 96),
                DNSCount(name: "updates.example.test", count: 74),
            ],
            topClients: [
                DNSCount(name: "Living room", count: 640),
                DNSCount(name: "Kitchen display", count: 410),
                DNSCount(name: "Office laptop", count: 380),
                DNSCount(name: "Upstairs speaker", count: 220),
            ],
            blockedDomains: [
                DNSCount(name: "ads.example.test", count: 420),
                DNSCount(name: "tracker.example.test", count: 180),
            ]
        )
    }()

    public static let emptyLookups = DNSDesk(
        textLogFileEnabled: false,
        blocking: DNSBlocking(enabled: true),
        day: [],
        knownClients: 0,
        listCount: 0,
        listsUpdatedAt: .streetFixtureNow,
        clients: [],
        groups: [],
        domains: [],
        lists: [],
        hosts: [],
        cnames: [],
        services: [],
        queries: [],
        topDomains: [],
        topClients: [],
        blockedDomains: []
    )

    /// No sample rows. The lists-updated line stays hidden until a real date arrives.
    public static var quiet: DNSDesk {
        var desk = emptyLookups
        desk.clientsNote = "Checking for devices using the Pi…"
        desk.listsUpdatedAt = .distantPast
        desk.listsUpdateKnown = false
        desk.textLogKnown = false
        return desk
    }

    public var blockingLine: String {
        if let spokenLine, !spokenLine.isEmpty {
            return spokenLine
        }
        if blocking.enabled {
            return "Ads are being blocked."
        }
        if let pause = blocking.pause {
            return "Ad blocking is paused for \(pause.title). It turns itself back on."
        }
        return "Ad blocking is paused."
    }
}
