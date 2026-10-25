import XCTest
@testable import StreetPiCore

final class HistoryAndLogTests: XCTestCase {
    private let ending = Date(timeIntervalSince1970: 1_700_000_000)

    func testHistoryKeepsTheBusyShareAndIgnoresIdle() throws {
        let stamp = Int(ending.timeIntervalSince1970 - 3_600)
        let body = """
        {"result":{"labels":["time","user","idle"],"data":[[\(stamp),20,80]]}}
        """
        let series = try NetdataHistory.series(
            from: NetdataReply(status: 200, body: Data(body.utf8)),
            kind: .processor,
            ending: ending
        )
        XCTAssertEqual(series.points.count, 24)
        XCTAssertEqual(series.points[23].value, 0.2, accuracy: 0.001)
        XCTAssertFalse(series.caption.localizedCaseInsensitiveContains("sample"))
        XCTAssertFalse(series.caption.localizedCaseInsensitiveContains("not live"))
    }

    func testMemoryUsesTheUsedShare() throws {
        let stamp = Int(ending.timeIntervalSince1970 - 60)
        let body = """
        {"labels":["time","free","used"],"data":[[\(stamp),75,25]]}
        """
        let series = try NetdataHistory.series(
            from: NetdataReply(status: 200, body: Data(body.utf8)),
            kind: .memory,
            ending: ending
        )
        XCTAssertEqual(series.points[23].value, 0.25, accuracy: 0.001)
    }

    func testRedirectAndHTMLAreFailedReads() {
        let redirect = NetdataReply(status: 302, body: Data("{}".utf8))
        XCTAssertThrowsError(try NetdataHistory.alarms(from: redirect)) { error in
            XCTAssertEqual(error as? NetdataProblem, .redirected)
        }
        let html = NetdataReply(status: 200, body: Data("<html>sign in</html>".utf8))
        XCTAssertThrowsError(try NetdataHistory.containers(from: html)) { error in
            XCTAssertEqual(error as? NetdataProblem, .notUnderstood)
        }
    }

    func testContainersAndAlarmsUsePlainWords() throws {
        let charts = """
        {"charts":{
          "system.cpu":{"id":"system.cpu","context":"system.cpu","type":"system"},
          "cgroup_docker_media_helper.cpu":{
            "id":"cgroup_docker_media_helper.cpu",
            "type":"cgroup_docker_media_helper",
            "context":"cgroup.cpu"
          },
          "cgroup_docker_media_helper.mem":{
            "id":"cgroup_docker_media_helper.mem",
            "type":"cgroup_docker_media_helper",
            "context":"cgroup.mem"
          }
        }}
        """
        let rows = try NetdataHistory.containers(from: NetdataReply(status: 200, body: Data(charts.utf8)))
        XCTAssertEqual(rows.map(\.name), ["media helper"])
        XCTAssertEqual(rows.map(\.detail), ["Running"])
        let ids = try NetdataHistory.chartIDs(from: NetdataReply(status: 200, body: Data(charts.utf8)))
        XCTAssertEqual(ids[.processor], "system.cpu")

        let alarms = """
        {"alarms":{
          "system.cpu.cpu":{"id":1,"chart":"system.cpu","status":"WARNING","info":"busy"},
          "disk_space._.disk":{"id":2,"chart":"disk_space._","status":"CRITICAL"},
          "system.ram.ram":{"id":3,"chart":"system.ram","status":"CLEAR"}
        }}
        """
        let raised = try NetdataHistory.alarms(from: NetdataReply(status: 200, body: Data(alarms.utf8)))
        XCTAssertEqual(raised.map(\.tone), [.problem, .attention])
        XCTAssertTrue(raised.contains { $0.sentence == "Warning. The processor is busy." })
        XCTAssertTrue(raised.contains { $0.sentence == "Critical. The disk is nearly full." })
        XCTAssertFalse(raised.contains { $0.sentence.localizedCaseInsensitiveContains("not live") })
    }

    func testLocalAgentRejectsCloudAndRedirectHosts() {
        XCTAssertNil(NetdataEndpoint(host: "app.netdata.cloud", port: 19999).url(for: "/api/v1/alarms"))
        XCTAssertNil(NetdataEndpoint.parsed("https://app.netdata.cloud"))
        XCTAssertNil(NetdataEndpoint.parsed("http://registry.my-netdata.io"))
        let local = NetdataEndpoint.houseDefault.url(for: "/api/v1/alarms")
        XCTAssertEqual(local?.scheme, "http")
        XCTAssertEqual(local?.port, 19999)
        XCTAssertFalse(NetdataHistoryAPI.chartsPath.contains("netdata.cloud"))
        XCTAssertTrue(NetdataHistoryAPI.dataPath(chart: "disk_space._")?.contains("chart=disk_space._") == true)
        XCTAssertTrue(NetdataAPI.routes.contains { $0.path == "/api/v1/charts" })
    }

    func testReaderSurvivesABadChartAndReadsAlarms() async {
        let ending = self.ending
        let stamp = Int(ending.timeIntervalSince1970 - 120)
        let reader = NetdataHistoryReader(transport: ScriptedAgent { path in
            if path == NetdataHistoryAPI.chartsPath {
                let body = #"{"charts":{"system.cpu":{"id":"system.cpu","context":"system.cpu"}}}"#
                return NetdataReply(status: 200, body: Data(body.utf8))
            }
            if path.contains("system.cpu") {
                let body = #"{"labels":["time","idle"],"data":[[\#(stamp),50]]}"#
                return NetdataReply(status: 200, body: Data(body.utf8))
            }
            if path == NetdataHistoryAPI.alarmsPath {
                let body = #"{"alarms":{"sensors.temperature.hot":{"chart":"sensors.temperature","status":"WARNING"}}}"#
                return NetdataReply(status: 200, body: Data(body.utf8))
            }
            return NetdataReply(status: 200, body: Data("<html></html>".utf8))
        }, now: { ending })
        let load = await reader.load()
        XCTAssertEqual(load.series.map(\.id), ["processor"])
        XCTAssertEqual(load.containers.map(\.name), [])
        XCTAssertNil(load.containerNote)
        XCTAssertEqual(load.alerts.first?.sentence, "Warning. The Pi is hot.")
        XCTAssertNil(load.alertNote)
        XCTAssertNil(load.chartNote)
    }

    func testOfflineReaderUsesPlainWords() async {
        let reader = NetdataHistoryReader(transport: ScriptedAgent { _ in
            throw NetdataProblem.offline
        })
        let load = await reader.load()
        XCTAssertEqual(load.chartNote, LiveReadCopy.offline)
        XCTAssertEqual(load.containerNote, LiveReadCopy.offline)
        XCTAssertEqual(load.alertNote, LiveReadCopy.offline)
        XCTAssertFalse(LiveReadCopy.charts.localizedCaseInsensitiveContains("not live"))
        XCTAssertTrue(load.series.isEmpty)
    }

    func testTextLogTailsAndLiveQueriesStaySeparate() async throws {
        let log = """
        {"log":[{"timestamp":10,"message":" gravity updated ","prio":"INFO"}],"nextID":4,"pid":9,"file":null}
        """
        let page = try PiholeDecode.textLog(from: Data(log.utf8))
        XCTAssertEqual(page.lines, ["gravity updated"])
        XCTAssertFalse(page.fileEnabled)
        XCTAssertEqual(page.nextID, 4)
        var feed = TextLogFeed()
        feed = feed.applying(page)
        let more = TextLogPage(lines: ["list refreshed"], nextID: 5, pid: 9, fileEnabled: true)
        feed = feed.applying(more)
        XCTAssertEqual(feed.lines, ["gravity updated", "list refreshed"])
        XCTAssertTrue(feed.fileEnabled)
        let restarted = feed.applying(TextLogPage(lines: ["fresh"], nextID: 1, pid: 10, fileEnabled: false))
        XCTAssertEqual(restarted.lines, ["fresh"])

        let transport = ScriptedPiholeTransport(steps: [
            .json(200, #"{"session":{"sid":"sid-a","validity":1800}}"#),
            .json(
                200,
                #"{"queries":[{"id":7,"domain":"news.example.test","status":"FORWARDED","time":20}]}"#
            ),
            .json(200, log),
        ])
        let client = PiholeClient(
            transport: transport,
            password: { "fixture-not-a-real-password" },
            now: { .streetFixtureNow }
        )
        let queries = try await client.liveQueries()
        XCTAssertEqual(queries.map(\.domain), ["news.example.test"])
        XCTAssertEqual(queries.first?.outcome, .allowed)
        let text = try await client.textLog(after: nil)
        XCTAssertEqual(text.lines, ["gravity updated"])
        let paths = transport.sent.map(\.path)
        XCTAssertTrue(paths.contains("/api/queries?length=40"))
        XCTAssertTrue(paths.contains("/api/logs/dnsmasq"))
        XCTAssertTrue(DNSAPI.routes.contains { $0.path == "/api/logs/dnsmasq" && $0.method == "GET" })
    }

    func testLiveFeedKeepsNewerLookups() {
        let older = DNSQuery(id: "1", domain: "old.example.test", client: "Kitchen", outcome: .allowed, at: ending)
        let newer = DNSQuery(
            id: "2",
            domain: "new.example.test",
            client: "Kitchen",
            outcome: .blocked,
            at: ending.addingTimeInterval(5)
        )
        let feed = LiveLogFeed(queries: [older]).applying([newer, older])
        XCTAssertEqual(feed.queries.map(\.id), ["2", "1"])
        XCTAssertEqual(DNSDesk.houseFixture.liveQueries.count, 3)
        XCTAssertNil(DNSDesk.houseFixture.liveFeed)
        XCTAssertFalse(DNSDesk.quiet.textLogKnown)
        XCTAssertEqual(DNSDesk.quiet.listsUpdatedAt, .distantPast)
        XCTAssertTrue(DNSDesk.quiet.services.isEmpty)
        XCTAssertEqual(MachineDesk.quiet.host, "This house")
        XCTAssertNotEqual(MachineDesk.quiet.host, MachineDesk.houseFixture.host)
    }

    func testNonJSONTextLogIsAFailedRead() {
        XCTAssertThrowsError(try PiholeDecode.textLog(from: Data("not-json".utf8))) { error in
            XCTAssertEqual(error as? PiholeProblem, .notUnderstood)
        }
    }
}

private struct ScriptedAgent: NetdataTransport {
    var send: @Sendable (String) async throws -> NetdataReply

    func get(_ path: String) async throws -> NetdataReply {
        try await send(path)
    }
}
