import XCTest
@testable import StreetPiCore

final class NetdataClientTests: XCTestCase {
    func testDefaultAddressIsTheHouseAgent() {
        let endpoint = NetdataEndpoint.houseDefault
        XCTAssertEqual(endpoint.host, "192.168.1.78")
        XCTAssertEqual(endpoint.port, 19_999)
        XCTAssertEqual(endpoint.display, "192.168.1.78")
        let info = endpoint.url(for: "/api/v1/info")
        XCTAssertEqual(info?.scheme, "http")
        XCTAssertEqual(info?.host, "192.168.1.78")
        XCTAssertEqual(info?.port, 19_999)
    }

    func testCloudAndSignedInAddressesAreRefused() {
        XCTAssertNil(NetdataEndpoint.parsed("https://app.netdata.cloud"))
        XCTAssertNil(NetdataEndpoint.parsed("http://registry.my-netdata.io"))
        XCTAssertNil(NetdataEndpoint.parsed("http://user:secret@192.168.1.78:19999"))
        XCTAssertFalse(NetdataEndpoint(host: "app.netdata.cloud", port: 443).isLocalAgent)
        XCTAssertNil(NetdataEndpoint(host: "app.netdata.cloud", port: 443).url(for: "/api/v1/info"))
    }

    func testAddressFieldParsesHostAndPort() {
        XCTAssertEqual(NetdataEndpoint.parsed("192.168.1.20")?.port, 19_999)
        XCTAssertEqual(NetdataEndpoint.parsed("http://192.168.1.20:19998")?.display, "192.168.1.20:19998")
        XCTAssertNil(NetdataEndpoint.parsed("   "))
    }

    func testDataPathStaysOnTheLocalAPI() {
        let cpu = NetdataAPI.dataPath(chart: "system.cpu")
        XCTAssertEqual(
            cpu,
            "/api/v1/data?chart=system.cpu&after=-5&points=1&group=average&format=json&options=jsonwrap"
        )
        let disk = NetdataAPI.dataPath(chart: "disk_space./", version: 2)
        XCTAssertTrue(disk.hasPrefix("/api/v2/data?chart=disk_space"))
        XCTAssertFalse(cpu.contains("netdata.cloud"))
        XCTAssertFalse(cpu.contains("192.168"))
    }

    func testHostNameComesFromInfo() throws {
        let named = Data(#"{"hostname":"house-pi"}"#.utf8)
        XCTAssertEqual(try NetdataDecode.hostName(from: named), "house-pi")
        let mirrored = Data(#"{"mirrored_hosts":["house-pi","other"]}"#.utf8)
        XCTAssertEqual(try NetdataDecode.hostName(from: mirrored), "house-pi")
    }

    func testHTMLAndRedirectsAreFailedReads() async {
        let html = NetdataReader(transport: MapTransport { path in
            if path == "/api/v1/info" {
                return NetdataReply(status: 200, body: Data("<!DOCTYPE html><html>sign in</html>".utf8))
            }
            return NetdataReply(status: 200, body: Data("not json".utf8))
        })
        await assertFailure(html, .notUnderstood)

        let redirect = NetdataReader(transport: MapTransport { _ in
            NetdataReply(status: 302, body: Data("<html>cloud</html>".utf8))
        })
        await assertFailure(redirect, .redirected)

        let down = NetdataReader(transport: MapTransport { _ in
            throw NetdataProblem.offline
        })
        await assertFailure(down, .offline)
    }

    func testMetersBindTemperatureCPUMemoryDiskAndUptime() async throws {
        let reader = NetdataReader(transport: MapTransport { path in
            try Self.reply(for: path)
        })
        let meters = try await reader.load()
        XCTAssertEqual(meters.hostName, "house-pi")
        XCTAssertEqual(meters.reading.cpuUsedFraction ?? 0, 0.18, accuracy: 0.001)
        XCTAssertEqual(meters.reading.memoryUsedFraction ?? 0, 0.41, accuracy: 0.001)
        XCTAssertEqual(meters.reading.diskUsedFraction ?? 0, 0.22, accuracy: 0.001)
        XCTAssertEqual(meters.reading.temperatureCelsius ?? 0, 47.2, accuracy: 0.01)
        XCTAssertEqual(meters.reading.uptimeSeconds ?? 0, 1_036_800, accuracy: 0.1)
        XCTAssertEqual(ReadingText.warmth(47.2), "Cool")
        XCTAssertEqual(ReadingText.warmth(65), "Warm")
        XCTAssertEqual(ReadingText.warmth(75), "Hot")
        XCTAssertTrue(meters.reading.hasSignal)
    }

    func testChartPlanPrefersRootDiskAndCPUTemperature() throws {
        let plan = NetdataDecode.chartPlan(from: Data(Self.chartsJSON.utf8))
        XCTAssertEqual(plan.cpu, "system.cpu")
        XCTAssertEqual(plan.memory, "system.ram")
        XCTAssertEqual(plan.disk, "disk_space./")
        XCTAssertEqual(plan.temperature, "sensors.temperature_cpu_thermal")
        XCTAssertEqual(plan.uptime, "system.uptime")
        XCTAssertEqual(NetdataDecode.chartPlan(from: nil), .fallback)
    }

    func testUnreadableChartFallsThroughToTheNextCandidate() async throws {
        let reader = NetdataReader(transport: MapTransport { path in
            if path == "/api/v1/info" {
                return NetdataReply(status: 200, body: Data(#"{"hostname":"house-pi"}"#.utf8))
            }
            if path.contains("/api/v1/charts") {
                return NetdataReply(status: 404, body: Data("missing".utf8))
            }
            if path.contains("chart=system.cpu&"), path.contains("/api/v1/") {
                return NetdataReply(status: 200, body: Data("<html>".utf8))
            }
            if path.contains("chart=system.cpu&"), path.contains("/api/v2/") {
                return NetdataReply(status: 200, body: Self.cpuBody)
            }
            if path.contains("chart=system.ram") {
                return NetdataReply(status: 200, body: Self.ramBody)
            }
            if path.contains("disk_space") {
                return NetdataReply(status: 404, body: Data(#"{"error":"missing"}"#.utf8))
            }
            if path.contains("system.uptime") {
                return NetdataReply(status: 200, body: Self.uptimeBody)
            }
            if path.contains("cpu.temperature") {
                return NetdataReply(status: 200, body: Self.temperatureBody)
            }
            return NetdataReply(status: 404, body: Data(#"{"error":"missing"}"#.utf8))
        })
        let meters = try await reader.load()
        XCTAssertEqual(meters.hostName, "house-pi")
        XCTAssertEqual(meters.reading.cpuUsedFraction ?? 0, 0.18, accuracy: 0.001)
        XCTAssertEqual(meters.reading.temperatureCelsius ?? 0, 47.2, accuracy: 0.01)
        XCTAssertNil(meters.reading.diskUsedFraction)
    }

    func testPlainSentencesDoNotCallTheReadingNotLive() {
        XCTAssertEqual(NetdataProblem.offline.sentence, "The Pi is not answering.")
        XCTAssertEqual(NetdataProblem.redirected.sentence, "The Pi is not answering.")
        XCTAssertEqual(NetdataProblem.notUnderstood.sentence, HouseReadingCopy.unreadableTitle)
        XCTAssertFalse(NetdataProblem.offline.sentence.localizedCaseInsensitiveContains("not live"))
        XCTAssertFalse(HouseReadingCopy.lookingTitle.localizedCaseInsensitiveContains("not live"))
    }

    private func assertFailure(
        _ reader: NetdataReader<MapTransport>,
        _ expected: NetdataProblem
    ) async {
        do {
            _ = try await reader.load()
            XCTFail("Expected a failed read")
        } catch let problem as NetdataProblem {
            XCTAssertEqual(problem, expected)
        } catch {
            XCTFail("Failed read threw \(error)")
        }
    }

    private static func reply(for path: String) throws -> NetdataReply {
        if path == "/api/v1/info" {
            return NetdataReply(status: 200, body: Data(#"{"hostname":"house-pi"}"#.utf8))
        }
        if path == "/api/v1/charts" {
            return NetdataReply(status: 200, body: Data(chartsJSON.utf8))
        }
        if path.contains("chart=system.cpu") { return NetdataReply(status: 200, body: cpuBody) }
        if path.contains("chart=system.ram") { return NetdataReply(status: 200, body: ramBody) }
        if path.contains("chart=disk_space") { return NetdataReply(status: 200, body: diskBody) }
        if path.contains("temperature_cpu_thermal") { return NetdataReply(status: 200, body: temperatureBody) }
        if path.contains("chart=system.uptime") { return NetdataReply(status: 200, body: uptimeBody) }
        throw NetdataProblem.offline
    }

    private static let chartsJSON = """
    {"charts":{
    "system.cpu":{"id":"system.cpu","context":"system.cpu"},
    "system.ram":{"id":"system.ram","context":"system.ram"},
    "disk_space./media":{"id":"disk_space./media","context":"disk.space","family":"/media"},
    "disk_space./":{"id":"disk_space./","context":"disk.space","family":"/"},
    "sensors.temperature_cpu_thermal":{
    "id":"sensors.temperature_cpu_thermal","context":"sensors.temperature","units":"Celsius","title":"CPU temperature"},
    "sensors.temperature_board_alarm":{
    "id":"sensors.temperature_board_alarm","context":"sensors.temperature","title":"temperature alarm"},
    "system.uptime":{"id":"system.uptime","context":"system.uptime"}
    }}
    """

    private static let cpuBody = Data(
        #"{"dimension_names":["user","system","idle"],"view_latest_values":[10,8,82]}"#.utf8
    )
    private static let ramBody = Data(
        #"{"dimension_names":["free","used","cached","buffers"],"view_latest_values":[500,410,70,20]}"#.utf8
    )
    private static let diskBody = Data(
        #"{"dimension_names":["avail","used","reserved_for_root"],"view_latest_values":[70,22,8]}"#.utf8
    )
    private static let temperatureBody = Data(
        #"{"labels":["time","temperature"],"data":[[1710000000,47.2]]}"#.utf8
    )
    private static let uptimeBody = Data(
        #"{"dimension_names":["uptime"],"latest_values":[1036800]}"#.utf8
    )
}

private struct MapTransport: NetdataTransport {
    var send: @Sendable (String) throws -> NetdataReply

    func get(_ path: String) async throws -> NetdataReply {
        try send(path)
    }
}
