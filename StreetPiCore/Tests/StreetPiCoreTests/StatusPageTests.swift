import XCTest
@testable import StreetPiCore

final class StatusPageTests: XCTestCase {
    private let now = Date.streetFixtureNow
    private let backupTime = "2026-10-13 08:17:00"

    func testInstalledAppReadsTheStatusPageAndTestsStayOnFixtures() {
        XCTAssertEqual(HouseRefreshSource.choose(underTest: false), .statusPage)
        XCTAssertEqual(HouseRefreshSource.choose(underTest: true), .fixtures)
    }

    func testHouseEndpointUsesTheStatusPagePath() throws {
        let endpoint = try XCTUnwrap(StatusPageEndpoint.house.cleaned())
        let page = try XCTUnwrap(endpoint.pagePath)
        let hearts = try XCTUnwrap(endpoint.heartbeatPath)
        XCTAssertEqual(page, "/api/status-page/house")
        XCTAssertEqual(hearts, "/api/status-page/heartbeat/house")
        let url = try XCTUnwrap(endpoint.url(path: page))
        XCTAssertEqual(url.absoluteString, "http://192.168.1.78:3001/api/status-page/house")
        let base = try XCTUnwrap(URL(string: "http://192.168.1.78:3001"))
        let made = try XCTUnwrap(StatusPageEndpoint.make(base: base, slug: "house"))
        XCTAssertEqual(made.pagePath, page)
        XCTAssertNil(StatusPageEndpoint(host: "bad host", port: 3001, slug: "house").cleaned())
        XCTAssertNil(StatusPageEndpoint(host: "192.168.1.78", port: 3001, slug: "../house").cleaned())
        XCTAssertNil(StatusPageEndpoint(host: "https://example.com", port: 3001, slug: "house").cleaned())
    }

    func testMissingPageDoesNotAskForHeartbeats() async throws {
        let transport = ScriptedStatusPageTransport(steps: [
            .json(404, #"{"error":"not found"}"#),
            .json(200, #"{"heartbeatList":{},"uptimeList":{}}"#),
        ])
        let load = try await reader(transport).load()
        XCTAssertTrue(load.board.isMissing)
        XCTAssertEqual(load.board.tiles.map(\.summary), Array(repeating: StatusPageCopy.notSetUp, count: 7))
        XCTAssertEqual(transport.paths, ["/api/status-page/house"])
        XCTAssertEqual(load.board.tiles.map(\.title), [
            "Monitors", "Streaming", "Smart home", "Remote", "Internet/DNS", "Address", "Backups",
        ])
    }

    func testHeartbeatAloneDoesNotMeanThePageExists() async throws {
        let transport = ScriptedStatusPageTransport(steps: [
            .json(404, ""),
        ])
        let load = try await reader(transport).load()
        XCTAssertTrue(load.board.isMissing)
        XCTAssertEqual(transport.paths.count, 1)
    }

    func testLivePageBindsBySectionName() async throws {
        let transport = ScriptedStatusPageTransport(steps: [
            .json(200, housePage(downFilm: true)),
            .json(200, houseBeats(filmStatus: 0)),
        ])
        let load = try await reader(transport).load()
        XCTAssertFalse(load.board.isMissing)
        XCTAssertEqual(tile("Streaming", load.board).summary, "Streaming is down.")
        XCTAssertEqual(tile("Streaming", load.board).tone, .problem)
        XCTAssertEqual(tile("Smart home", load.board).summary, "Smart home is up.")
        XCTAssertEqual(tile("Remote", load.board).summary, "Remote help is up.")
        XCTAssertEqual(tile("Internet/DNS", load.board).summary, "Internet is up.")
        XCTAssertEqual(tile("Monitors", load.board).summary, "6 of 7 up")
        XCTAssertEqual(tile("Monitors", load.board).tone, .problem)
        XCTAssertEqual(tile("Address", load.board).summary, "The home's address on the internet is up to date.")
        XCTAssertEqual(tile("Backups", load.board).summary, "Last backup: Tue 3:17 AM")
        XCTAssertEqual(tile("Backups", load.board).tone, .calm)
        XCTAssertEqual(transport.paths, [
            "/api/status-page/house",
            "/api/status-page/heartbeat/house",
        ])
    }

    func testNamesWinOverMonitorIds() async throws {
        let page = """
        {"config":{"title":"House","published":true},"publicGroupList":[
        {"id":1,"name":"Streaming","weight":1,"monitorList":[
        {"id":10,"name":"DuckDNS points home","type":"http","sendUrl":0},
        {"id":34,"name":"Weekly SD backup","type":"push"}]},
        {"id":9,"name":"Internet","monitorList":[
        {"id":99,"name":"DuckDNS points home","type":"http"}]},
        {"id":8,"name":"Backups","monitorList":[
        {"id":7,"name":"Weekly SD backup","type":"push"}]}
        ]}
        """
        let beats = """
        {"heartbeatList":{
        "10":[{"status":0,"time":"\(backupTime)","ping":null}],
        "34":[{"status":0,"time":"\(backupTime)"}],
        "99":[{"status":1,"time":"\(backupTime)","msg":"ok"}],
        "7":[{"status":1,"time":"\(backupTime)"}]
        },"uptimeList":{}}
        """
        let transport = ScriptedStatusPageTransport(steps: [.json(200, page), .json(200, beats)])
        let load = try await reader(transport).load()
        XCTAssertEqual(tile("Address", load.board).tone, .calm)
        XCTAssertEqual(tile("Backups", load.board).summary, "Last backup: Tue 3:17 AM")
        XCTAssertEqual(tile("Streaming", load.board).summary, "Streaming is down.")
    }

    func testBackupGoesDownAfterEightDaysWithoutACheckIn() async throws {
        let stale = now.addingTimeInterval(-(StatusPageCopy.backupLimit + 3_600))
        let fresh = now.addingTimeInterval(-(StatusPageCopy.backupLimit - 3_600))
        let staleLoad = try await backupLoad(success: stale, latestStatus: 0)
        XCTAssertEqual(staleLoad.tone, .problem)
        XCTAssertTrue(staleLoad.summary.hasPrefix("No backup in the last 8 days. Last backup:"))

        let freshLoad = try await backupLoad(success: fresh, latestStatus: 0)
        XCTAssertEqual(freshLoad.tone, .calm)
        XCTAssertTrue(freshLoad.summary.hasPrefix("Last backup:"))
        XCTAssertFalse(freshLoad.summary.contains("8 days"))

        let waiting = try await backupLoad(success: nil, latestStatus: 0)
        XCTAssertEqual(waiting.summary, "No backup check-in yet.")
        XCTAssertEqual(waiting.tone, .attention)
    }

    func testTwentyEightMonitors() async throws {
        let monitors = (1...28).map { id in
            #"{"id":\#(id),"name":"Monitor \#(id)","type":"http"}"#
        }.joined(separator: ",")
        let beats = (1...28).map { id in
            #""\#(id)":[{"status":1,"time":"\#(backupTime)"}]"#
        }.joined(separator: ",")
        let page = """
        {"config":{"title":"House","published":true},"publicGroupList":[
        {"name":"Streaming","monitorList":[\(monitors)]}]}
        """
        let transport = ScriptedStatusPageTransport(steps: [
            .json(200, page),
            .json(200, #"{"heartbeatList":{\#(beats)}}"#),
        ])
        let load = try await reader(transport).load()
        XCTAssertEqual(tile("Monitors", load.board).summary, "28 of 28 up")
        XCTAssertEqual(tile("Monitors", load.board).tone, .calm)
        XCTAssertEqual(tile("Smart home", load.board).summary, StatusPageCopy.notSetUp)
    }

    func testPendingIsNotUpAndABadPageIsAFailedRead() async throws {
        let page = housePage(downFilm: false)
        let beats = houseBeats(filmStatus: 2)
        let transport = ScriptedStatusPageTransport(steps: [.json(200, page), .json(200, beats)])
        let load = try await reader(transport).load()
        XCTAssertEqual(tile("Monitors", load.board).summary, "6 of 7 up")
        XCTAssertEqual(tile("Streaming", load.board).summary, "Streaming is still checking.")
        XCTAssertEqual(tile("Streaming", load.board).tone, .attention)

        let broken = ScriptedStatusPageTransport(steps: [
            .json(200, "<html>nope</html>"),
        ])
        do {
            _ = try await reader(broken).load()
            XCTFail("A non-JSON page should fail the read")
        } catch StatusPageProblem.notUnderstood {
            XCTAssertEqual(broken.paths, ["/api/status-page/house"])
        }

        let heartFailed = ScriptedStatusPageTransport(steps: [
            .json(200, page),
            .json(500, "nope"),
        ])
        do {
            _ = try await reader(heartFailed).load()
            XCTFail("A failed heartbeat is not a missing page")
        } catch StatusPageProblem.offline {
            XCTAssertEqual(heartFailed.paths.count, 2)
        }
    }

    func testPreviewSpeaksInPlainWords() {
        let board = StatusPageFixture.previewBoard(now: now)
        XCTAssertEqual(tile("Monitors", board).summary, "6 of 6 up")
        XCTAssertEqual(tile("Streaming", board).summary, "Streaming is up.")
        XCTAssertEqual(tile("Backups", board).summary, "Last backup: Tue 3:17 AM")
        XCTAssertEqual(
            tile("Address", board).summary,
            "The home's address on the internet is up to date."
        )
        XCTAssertFalse(board.isMissing)
    }

    func testClockReadsTuesdayMorningInChicago() throws {
        let parsed = try XCTUnwrap(KumaClock.parse("2026-10-27T08:17:00.000Z"))
        XCTAssertEqual(BackupClock.phrase(parsed), "Tue 3:17 AM")
        let spaced = try XCTUnwrap(KumaClock.parse("2026-10-27 08:17:00"))
        XCTAssertEqual(parsed, spaced)
    }

    private func reader(_ transport: ScriptedStatusPageTransport) -> StatusPageReader<ScriptedStatusPageTransport> {
        let moment = now
        return StatusPageReader(transport: transport, endpoint: .house, now: { moment })
    }

    private func tile(_ title: String, _ board: HouseStatusBoard) -> HouseStatusTile {
        guard let tile = board.tiles.first(where: { $0.title == title }) else {
            XCTFail("Missing \(title)")
            return HouseStatusTile(id: .monitors, title: title, summary: "", tone: .attention, rows: [])
        }
        return tile
    }

    private func backupLoad(success: Date?, latestStatus: Int) async throws -> HouseStatusTile {
        let stamp = success.map { iso($0) } ?? backupTime
        let status = success == nil ? latestStatus : 1
        let extra = success == nil ? "" : #",{"status":\#(latestStatus),"time":"\#(iso(now))"}"#
        let page = """
        {"config":{"title":"House","published":true},"publicGroupList":[
        {"name":"Backups","monitorList":[{"id":6,"name":"Weekly SD backup","type":"push"}]}]}
        """
        let beats = """
        {"heartbeatList":{"6":[{"status":\(status),"time":"\(stamp)"}\(extra)]}}
        """
        let transport = ScriptedStatusPageTransport(steps: [.json(200, page), .json(200, beats)])
        return tile("Backups", try await reader(transport).load().board)
    }

    private func iso(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }

    private func housePage(downFilm: Bool) -> String {
        let film = downFilm ? "Films" : "Films"
        return """
        {"config":{"slug":"house","title":"House","description":"","published":true},
        "incident":null,"maintenanceList":[],
        "publicGroupList":[
        {"name":"Streaming","monitorList":[
        {"id":1,"name":"\(film)","type":"http","sendUrl":0},
        {"id":8,"name":"Music","type":"http"}]},
        {"name":"smart home","monitorList":[{"id":2,"name":"Lights","type":"http"}]},
        {"name":"Remote help","monitorList":[{"id":3,"name":"Desk","type":"ping"}]},
        {"name":"Internet","monitorList":[
        {"id":42,"name":"DuckDNS points home","type":"http"},
        {"id":5,"name":"Name lookup","type":"dns"}]},
        {"name":"Backups","monitorList":[{"id":99,"name":"Weekly SD backup","type":"push"}]}
        ]}
        """
    }

    private func houseBeats(filmStatus: Int) -> String {
        """
        {"heartbeatList":{
        "1":[{"status":\(filmStatus),"time":"\(backupTime)","msg":"","ping":12}],
        "8":[{"status":1,"time":"\(backupTime)"}],
        "2":[{"status":1,"time":"\(backupTime)"}],
        "3":[{"status":1,"time":"\(backupTime)"}],
        "42":[{"status":1,"time":"\(backupTime)"}],
        "5":[{"status":1,"time":"\(backupTime)"}],
        "99":[{"status":1,"time":"\(backupTime)","ping":null}]
        },"uptimeList":{"99_24":1}}
        """
    }
}
