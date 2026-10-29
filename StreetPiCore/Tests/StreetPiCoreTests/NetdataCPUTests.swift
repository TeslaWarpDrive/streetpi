import XCTest
@testable import StreetPiCore

/// Netdata hides `idle` on `system.cpu` unless the query asks for hidden dimensions.
final class NetdataCPUTests: XCTestCase {
    private let ending = Date(timeIntervalSince1970: 1_700_000_000)

    func testDefaultReplyWithoutIdleIsTheBusyShare() throws {
        let point = try NetdataDecode.point(from: Data(Self.withoutIdle.utf8))
        XCTAssertFalse(point.names.contains("idle"))
        let busy = try XCTUnwrap(NetdataDecode.cpuFraction(point))
        XCTAssertEqual(busy, 0.0452, accuracy: 0.0005)
        XCTAssertLessThan(busy, 1)
    }

    func testReplyWithHiddenIdleGivesTheSameShare() throws {
        let point = try NetdataDecode.point(from: Data(Self.withIdle.utf8))
        XCTAssertTrue(point.names.contains("idle"))
        let busy = try XCTUnwrap(NetdataDecode.cpuFraction(point))
        XCTAssertEqual(busy, 0.0452, accuracy: 0.0005)
    }

    func testResultTableWithoutViewValuesIsReadToo() throws {
        let body = """
        {"api":1,"id":"system.cpu","result":{"labels":["time","softirq","user","system","iowait"],\
        "data":[[1700000000,0.5,20.25,9.75,1.5]]}}
        """
        let point = try NetdataDecode.point(from: Data(body.utf8))
        XCTAssertEqual(NetdataDecode.cpuFraction(point) ?? 0, 0.32, accuracy: 0.0001)
    }

    func testQuietAndFullyBusyProcessors() {
        let quiet = NetdataPoint(names: ["user", "system"], values: [0, 0])
        XCTAssertEqual(NetdataDecode.cpuFraction(quiet), 0)
        let pegged = NetdataPoint(names: ["user", "system", "idle"], values: [70, 30, 0])
        XCTAssertEqual(NetdataDecode.cpuFraction(pegged), 1)
        let onlyIdle = NetdataPoint(names: ["idle"], values: [88])
        XCTAssertEqual(NetdataDecode.cpuFraction(onlyIdle) ?? 0, 0.12, accuracy: 0.0001)
        XCTAssertNil(NetdataDecode.cpuFraction(NetdataPoint(names: [], values: [])))
    }

    func testMetersNoLongerReadAFullProcessor() async throws {
        let reader = NetdataReader(transport: CPUAgent { path in
            if path == "/api/v1/info" {
                return NetdataReply(status: 200, body: Data(#"{"hostname":"fixture-pi"}"#.utf8))
            }
            if path.contains("chart=system.cpu&") {
                return NetdataReply(status: 200, body: Data(Self.withoutIdle.utf8))
            }
            return NetdataReply(status: 404, body: Data(#"{"error":"missing"}"#.utf8))
        })
        let meters = try await reader.load()
        XCTAssertEqual(meters.reading.cpuUsedFraction ?? 1, 0.0452, accuracy: 0.0005)
    }

    func testDayChartWithoutIdleKeepsLowHoursLow() throws {
        let stamp = Int(ending.timeIntervalSince1970 - 1_800)
        let body = """
        {"api":1,"id":"system.cpu","result":{"labels":["time","softirq","irq","user","system","iowait"],\
        "data":[[\(stamp),0.1,0,0.7,0.4,0]]}}
        """
        let series = try NetdataHistory.series(
            from: NetdataReply(status: 200, body: Data(body.utf8)),
            kind: .processor,
            ending: ending
        )
        XCTAssertEqual(series.points[23].value, 0.012, accuracy: 0.0001)
    }

    func testDayChartWithIdleMatches() throws {
        let stamp = Int(ending.timeIntervalSince1970 - 1_800)
        let body = """
        {"result":{"labels":["time","user","system","idle"],"data":[[\(stamp),30,12,58]]}}
        """
        let series = try NetdataHistory.series(
            from: NetdataReply(status: 200, body: Data(body.utf8)),
            kind: .processor,
            ending: ending
        )
        XCTAssertEqual(series.points[23].value, 0.42, accuracy: 0.0001)
    }

    /// The shape `/api/v1/data?chart=system.cpu&...&options=jsonwrap` returns by default.
    private static let withoutIdle = """
    {"api":1,"id":"system.cpu","name":"system.cpu","view_update_every":1,"update_every":1,\
    "first_entry":1699990000,"last_entry":1700000000,"before":1700000000,"after":1699999996,\
    "dimension_names":["guest_nice","guest","steal","softirq","irq","user","system","nice","iowait"],\
    "dimension_ids":["guest_nice","guest","steal","softirq","irq","user","system","nice","iowait"],\
    "latest_values":[0,0,0,0.2512563,0,2.763819,1.507538,0,0],\
    "view_latest_values":[0,0,0,0.2512563,0,2.763819,1.507538,0,0],\
    "dimensions":9,"points":1,"format":"json",\
    "result":{"labels":["time","guest_nice","guest","steal","softirq","irq","user","system","nice","iowait"],\
    "data":[[1700000000,0,0,0,0.2512563,0,2.763819,1.507538,0,0]]},"min":0,"max":2.763819}
    """

    /// The same moment with `showhidden`, which adds `idle`.
    private static let withIdle = """
    {"api":1,"id":"system.cpu","name":"system.cpu",\
    "dimension_names":["guest_nice","guest","steal","softirq","irq","user","system","nice","iowait","idle"],\
    "view_latest_values":[0,0,0,0.2512563,0,2.763819,1.507538,0,0,95.477387],\
    "result":{"labels":["time","guest_nice","guest","steal","softirq","irq","user","system","nice","iowait","idle"],\
    "data":[[1700000000,0,0,0,0.2512563,0,2.763819,1.507538,0,0,95.477387]]}}
    """
}

private struct CPUAgent: NetdataTransport {
    var send: @Sendable (String) -> NetdataReply

    func get(_ path: String) async throws -> NetdataReply {
        send(path)
    }
}
