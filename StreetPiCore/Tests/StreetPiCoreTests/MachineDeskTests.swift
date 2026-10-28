import XCTest
@testable import StreetPiCore

final class MachineDeskTests: XCTestCase {
    func testFixtureStaysOffTheRealNetwork() {
        let desk = MachineDesk.houseFixture
        XCTAssertEqual(desk.host, "fixture.local")
        XCTAssertFalse(desk.host.contains("192.168"))
        XCTAssertEqual(desk.series.count, 4)
        XCTAssertEqual(desk.series.first?.points.count, 24)
        XCTAssertTrue(desk.alerts.isEmpty)
        let paths = NetdataAPI.routes.map(\.path) + [StatusPageAPI.route.path]
        XCTAssertTrue(paths.allSatisfy { !$0.contains("://") && !$0.contains("192.168") })
        XCTAssertTrue(paths.contains("/api/v1/alarms"))
        XCTAssertTrue(paths.contains("/api/v3/data"))
        XCTAssertTrue(paths.contains("/api/status-page/house"))
        XCTAssertTrue(NetdataAPI.chartFamilies.contains("system.uptime"))
        XCTAssertTrue(NetdataAPI.chartFamilies.contains("cgroup.docker"))
    }

    func testStatusIsAReading() {
        let desk = MachineDesk.houseFixture
        XCTAssertEqual(desk.services.map(\.detail), ["Up", "Up", "Up"])
        XCTAssertEqual(desk.containers.map(\.detail), ["Running", "Running"])
        XCTAssertFalse(desk.services.contains { $0.detail.contains("Stop") })
    }

    func testAlertTimeIsOptional() throws {
        let plain = HouseAlert(id: "cpu", sentence: "Warning. The processor is busy.", tone: .attention)
        XCTAssertNil(plain.raisedAt)

        let stamp = Date(timeIntervalSince1970: 1_792_420_000)
        let timed = HouseAlert(id: "disk", sentence: "Critical. The disk is nearly full.", tone: .problem, raisedAt: stamp)
        let data = try StreetJSON.encoder().encode(timed)
        let decoded = try StreetJSON.decoder().decode(HouseAlert.self, from: data)
        XCTAssertEqual(decoded, timed)

        let older = Data(#"{"id":"temp","sentence":"Warning. The Pi is hot.","tone":"attention"}"#.utf8)
        let untimed = try StreetJSON.decoder().decode(HouseAlert.self, from: older)
        XCTAssertNil(untimed.raisedAt)
        XCTAssertEqual(untimed.tone, .attention)
    }

    func testMachineLineReadsLikeASubline() {
        XCTAssertEqual(ReadingText.machineLine(model: "Pi 5", uptimeSeconds: 1_036_800), "Pi 5 · up 12 days")
        XCTAssertEqual(ReadingText.machineLine(model: "Pi 5", uptimeSeconds: nil), "Pi 5")
        XCTAssertEqual(ReadingText.machineLine(model: " ", uptimeSeconds: 7_200), "Up 2 hours")
    }

    func testRingWords() {
        XCTAssertEqual(ReadingText.processorWord(0.18), "Light")
        XCTAssertEqual(ReadingText.processorWord(0.6), "Steady")
        XCTAssertEqual(ReadingText.processorWord(0.9), "Busy")
        XCTAssertEqual(ReadingText.roomWord(0.41, limit: MachineLimits.memoryAttention), "Room to spare")
        XCTAssertEqual(ReadingText.roomWord(0.95, limit: MachineLimits.diskAttention), "Almost full")
    }
}
