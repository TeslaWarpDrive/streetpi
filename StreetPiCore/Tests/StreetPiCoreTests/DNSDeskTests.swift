import XCTest
@testable import StreetPiCore

final class DNSDeskTests: XCTestCase {
    func testTextLogOffStillKeepsLookups() {
        let desk = DNSDesk.houseFixture
        XCTAssertFalse(desk.textLogFileEnabled)
        XCTAssertTrue(desk.hasDayLookups)
        XCTAssertEqual(desk.day.count, 24)
        XCTAssertGreaterThan(desk.queriesToday, 0)
        XCTAssertGreaterThan(desk.blockedToday, 0)
        XCTAssertFalse(desk.queries.isEmpty)
        XCTAssertFalse(desk.topDomains.isEmpty)
        XCTAssertFalse(desk.topClients.isEmpty)
        XCTAssertEqual(desk.queriesToday, desk.day.reduce(0) { $0 + $1.allowed + $1.blocked })
        XCTAssertFalse(DNSCopy.emptyQueriesDetail.localizedCaseInsensitiveContains("logging"))
        XCTAssertFalse(DNSCopy.emptyTopsDetail.localizedCaseInsensitiveContains("logging"))
        XCTAssertFalse(DNSCopy.emptyChartDetail.localizedCaseInsensitiveContains("sample"))
        XCTAssertTrue(DNSCopy.upkeepDetail.contains("still kept"))
        XCTAssertTrue(DNSCopy.upkeepDetail.contains("July"))
    }

    func testEmptyLookupsStayQuietWithoutBlamingTheLog() {
        let desk = DNSDesk.emptyLookups
        XCTAssertFalse(desk.hasDayLookups)
        XCTAssertTrue(desk.queries.isEmpty)
        XCTAssertTrue(desk.liveQueries.isEmpty)
        let copy = [
            DNSCopy.emptyQueriesTitle, DNSCopy.emptyQueriesDetail,
            DNSCopy.emptyLiveTitle, DNSCopy.emptyLiveDetail,
            DNSCopy.emptyTopsTitle, DNSCopy.emptyTopsDetail,
            DNSCopy.emptyChartTitle, DNSCopy.emptyChartDetail,
        ].joined(separator: " ")
        XCTAssertFalse(copy.localizedCaseInsensitiveContains("logging is off"))
        XCTAssertFalse(copy.localizedCaseInsensitiveContains("query logging"))
    }

    func testFixtureNamesStayOnTheSampleHost() {
        let desk = DNSDesk.houseFixture
        XCTAssertTrue(desk.lists.allSatisfy { $0.host == "fixture.local" })
        let blob = [
            desk.clients.map(\.name),
            desk.domains.map(\.name),
            desk.hosts.map(\.name),
            desk.cnames.map(\.name),
            desk.queries.map(\.domain),
            desk.lists.map(\.host),
        ].flatMap { $0 }.joined(separator: " ")
        XCTAssertFalse(blob.contains("192.168"))
        XCTAssertFalse(blob.localizedCaseInsensitiveContains("bradley"))
        XCTAssertFalse(blob.localizedCaseInsensitiveContains("brandy"))
    }

    func testRoutesKeepReadsAndOnlyThreeWrites() {
        let paths = DNSAPI.routes.map(\.path)
        XCTAssertTrue(paths.contains("/api/auth"))
        XCTAssertTrue(paths.contains("/api/stats/summary"))
        XCTAssertTrue(paths.contains("/api/history"))
        XCTAssertTrue(paths.contains("/api/dns/blocking"))
        XCTAssertTrue(paths.contains("/api/queries"))
        XCTAssertTrue(paths.contains("/api/stats/top_domains"))
        XCTAssertTrue(paths.contains("/api/stats/top_clients"))
        XCTAssertTrue(paths.contains("/api/config/dns/hosts"))
        XCTAssertTrue(paths.contains("/api/config/dns/cnameRecords"))
        XCTAssertTrue(paths.contains("/api/domains/deny/exact"))
        XCTAssertTrue(paths.contains("/api/domains/allow/exact"))
        let writes = DNSAPI.routes.filter { $0.method != "GET" }.map(\.path)
        XCTAssertEqual(
            Set(writes),
            [
                "/api/auth",
                "/api/dns/blocking",
                "/api/domains/deny/exact",
                "/api/domains/allow/exact",
                "/api/action/gravity",
            ]
        )
        XCTAssertTrue(DNSAPI.routes.allSatisfy { $0.method != "PATCH" && $0.method != "PUT" })
        XCTAssertTrue(DNSAPI.routes.allSatisfy { !$0.path.contains("192.168") && !$0.path.contains("://") })
        XCTAssertFalse(DNSAPI.routes.contains { $0.path.contains("restart") || $0.path.contains("flush") })
        XCTAssertFalse(DNSAPI.routes.contains { $0.path.contains("teleporter") })
    }

    func testPauseBlockAndAllowStayOnTheFixture() throws {
        let paused = DNSDesk.houseFixture.applying(.pauseAdBlocking(.fiveMinutes))
        XCTAssertFalse(paused.blocking.enabled)
        XCTAssertEqual(paused.blocking.pause, .fiveMinutes)
        XCTAssertFalse(paused.textLogFileEnabled)
        let blocked = paused.applying(.blockDomain(named: "track.example.test"))
        XCTAssertTrue(blocked.domains.contains { $0.name == "track.example.test" && $0.detail == "Blocked" })
        let allowed = blocked.applying(.allowDomain(named: "news.example.test"))
        XCTAssertTrue(allowed.domains.contains { $0.name == "news.example.test" && $0.detail == "Allowed" })
        XCTAssertEqual(allowed.lists.count, DNSDesk.houseFixture.lists.count)
        let lists = allowed.applying(.updateBlockLists)
        XCTAssertEqual(lists.listsUpdatedAt, .streetFixtureNow)
        XCTAssertFalse(lists.blocking.enabled)
        XCTAssertEqual(lists.blocking.pause, .fiveMinutes)
        let custom = try XCTUnwrap(PauseLength(seconds: 90))
        XCTAssertEqual(custom.title, "90 seconds")
        XCTAssertNil(PauseLength(seconds: 0))
        XCTAssertFalse(PauseLength.presets.contains { $0.title.localizedCaseInsensitiveContains("until") })
    }

    func testThereIsNoPiSideAsk() {
        XCTAssertTrue(PiSideAsk.changes.isEmpty)
        XCTAssertFalse(DNSDesk.houseFixture.textLogFileEnabled)
        XCTAssertFalse(DNSDesk.houseFixture.queries.isEmpty)
    }

    func testPagesCoverTheDesk() {
        let pages = DNSShelf.allCases.flatMap(\.pages)
        XCTAssertEqual(Set(pages), Set(DNSPage.allCases))
        XCTAssertEqual(DNSPage.today.title, "Today")
        XCTAssertTrue(DNSPage.queryLog.blurb.contains("kept"))
        XCTAssertTrue(DNSPage.upkeep.blurb.contains("block lists"))
        XCTAssertTrue(DNSPage.upkeep.blurb.contains("stay as they are"))
    }

    func testBannedPhrasesAreGone() throws {
        let repo = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let banned = [
            "Query logging is off",
            "logging is off",
            "live chart would be empty",
            "untilTurnedBackOn",
            "Until it's turned back on",
            "NSAllowsArbitraryLoads",
            "/api/action/restartdns",
            "/api/action/flush",
            "/api/teleporter",
            "Restart DNS",
        ]
        var hits: [String] = []
        for folder in ["StreetPi", "StreetPiCore/Sources"] {
            let root = repo.appendingPathComponent(folder)
            let files = try FileManager.default.subpathsOfDirectory(atPath: root.path)
            for file in files where file.hasSuffix(".swift") || file.hasSuffix(".plist") {
                let text = try String(contentsOf: root.appendingPathComponent(file), encoding: .utf8)
                for phrase in banned where text.contains(phrase) {
                    hits.append("\(folder)/\(file): \(phrase)")
                }
            }
        }
        XCTAssertEqual(hits, [])
    }
}
