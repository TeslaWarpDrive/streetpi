import Foundation
import XCTest
@testable import StreetPiCore

final class AwaySnapshotTests: XCTestCase {
    private func json(replacing key: String, with value: Any?) throws -> Data {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: fixtureData()) as? [String: Any])
        object[key] = value ?? NSNull()
        return try JSONSerialization.data(withJSONObject: object)
    }

    private func fixtureData() throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "away-live", withExtension: "json"))
        return try Data(contentsOf: url)
    }

    private func decode(_ data: Data) throws -> AwaySnapshot {
        try JSONDecoder().decode(AwaySnapshot.self, from: data)
    }

    func testDecodesTheLiveFixture() throws {
        let snapshot = try FixtureBook.away(named: "away-live")
        XCTAssertEqual(snapshot.kind, .live)
        XCTAssertEqual(snapshot.generatedAt, Date.streetFixtureNow.addingTimeInterval(-12))
        XCTAssertEqual(snapshot.adBlocker?.blocking, .enabled)
        XCTAssertEqual(snapshot.adBlocker?.queriesToday, 41_234)
        XCTAssertNil(snapshot.adBlocker?.history)
        XCTAssertEqual(snapshot.machine?.temperatureC, 52.1)
        XCTAssertEqual(snapshot.monitors?.items.count, 8)
        XCTAssertEqual(snapshot.sources.machine, .ok)
    }

    func testDecodesTheHistoryFixture() throws {
        let snapshot = try FixtureBook.away(named: "away-history")
        XCTAssertEqual(snapshot.kind, .history)
        XCTAssertEqual(snapshot.adBlocker?.history?.count, 144)
        XCTAssertEqual(snapshot.machine?.cpuHistory?.count, 96)
    }

    func testRoundTripsThroughJSON() throws {
        for name in ["away-live", "away-history"] {
            let snapshot = try FixtureBook.away(named: name)
            let again = try decode(JSONEncoder().encode(snapshot))
            XCTAssertEqual(again, snapshot)
        }
    }

    func testTakesFractionsOfASecond() throws {
        let snapshot = try decode(json(replacing: "generatedAt", with: "2026-10-30T19:40:00.250Z"))
        XCTAssertEqual(snapshot.generatedAt.timeIntervalSince1970.truncatingRemainder(dividingBy: 1), 0.25, accuracy: 0.001)
    }

    func testRejectsAnUnknownKeyAtTheTop() throws {
        XCTAssertThrowsError(try decode(json(replacing: "clientName", with: "fixture-laptop")))
    }

    func testRejectsAnUnknownKeyInsideAPart() throws {
        var part = try XCTUnwrap(
            (JSONSerialization.jsonObject(with: fixtureData()) as? [String: Any])?["machine"] as? [String: Any]
        )
        part["hostname"] = "fixture-host"
        XCTAssertThrowsError(try decode(json(replacing: "machine", with: part)))
    }

    func testRejectsAnUnknownKeyInsideAMonitor() throws {
        let monitors: [String: Any] = [
            "up": 1, "down": 0, "total": 1,
            "items": [["name": "Check", "status": "up", "ip": "192.0.2.10"]],
        ]
        XCTAssertThrowsError(try decode(json(replacing: "monitors", with: monitors)))
    }

    func testRejectsMonitorUpGreaterThanTotal() throws {
        let monitors: [String: Any] = [
            "up": 5, "down": 0, "total": 0, "items": [Any](),
        ]
        XCTAssertThrowsError(try decode(json(replacing: "monitors", with: monitors)))
    }

    func testRejectsAllUpCountsWhileANamedMonitorIsDown() throws {
        let monitors: [String: Any] = [
            "up": 2, "down": 0, "total": 2,
            "items": [
                ["name": "Ad blocker", "status": "up"],
                ["name": "Internet", "status": "down"],
            ],
        ]
        XCTAssertThrowsError(try decode(json(replacing: "monitors", with: monitors)))
    }

    func testAcceptsAShorterMonitorList() throws {
        let monitors: [String: Any] = [
            "up": 4, "down": 1, "total": 10,
            "items": [
                ["name": "Ad blocker", "status": "up"],
                ["name": "Internet", "status": "down"],
            ],
        ]
        let snapshot = try decode(json(replacing: "monitors", with: monitors))
        XCTAssertEqual(snapshot.monitors?.up, 4)
        XCTAssertEqual(snapshot.monitors?.total, 10)
        XCTAssertEqual(snapshot.monitors?.items.count, 2)
    }

    func testRejectsMonitorDownGreaterThanTotal() throws {
        let monitors: [String: Any] = [
            "up": 1, "down": 9, "total": 2,
            "items": [["name": "Internet", "status": "down"]],
        ]
        XCTAssertThrowsError(try decode(json(replacing: "monitors", with: monitors)))
    }

    func testRejectsAllUpCountsWhileANamedMonitorIsPending() throws {
        let monitors: [String: Any] = [
            "up": 1, "down": 0, "total": 1,
            "items": [["name": "Ad blocker", "status": "pending"]],
        ]
        XCTAssertThrowsError(try decode(json(replacing: "monitors", with: monitors)))
    }

    func testRejectsAllUpCountsWhileANamedMonitorIsInMaintenance() throws {
        let monitors: [String: Any] = [
            "up": 2, "down": 0, "total": 2,
            "items": [
                ["name": "Ad blocker", "status": "up"],
                ["name": "Weekly backup", "status": "maintenance"],
            ],
        ]
        XCTAssertThrowsError(try decode(json(replacing: "monitors", with: monitors)))
    }

    func testAcceptsAPendingCheckWhenTheCountIsNotAllUp() throws {
        let monitors: [String: Any] = [
            "up": 1, "down": 0, "total": 2,
            "items": [["name": "Ad blocker", "status": "pending"]],
        ]
        let snapshot = try decode(json(replacing: "monitors", with: monitors))
        XCTAssertEqual(snapshot.monitors?.up, 1)
        XCTAssertEqual(snapshot.monitors?.total, 2)
        XCTAssertEqual(snapshot.monitors?.items.first?.status, .pending)
    }

    func testAcceptsADownCountEqualToTheTotal() throws {
        let monitors: [String: Any] = [
            "up": 0, "down": 2, "total": 2,
            "items": [["name": "Internet", "status": "down"]],
        ]
        let snapshot = try decode(json(replacing: "monitors", with: monitors))
        XCTAssertEqual(snapshot.monitors?.down, 2)
        XCTAssertEqual(snapshot.monitors?.total, 2)
    }

    func testAcceptsMaintenanceWhenTheCountAdmitsADown() throws {
        let monitors: [String: Any] = [
            "up": 1, "down": 1, "total": 2,
            "items": [["name": "Weekly backup", "status": "maintenance"]],
        ]
        let snapshot = try decode(json(replacing: "monitors", with: monitors))
        XCTAssertEqual(snapshot.monitors?.items.first?.status, .maintenance)
    }

    func testRejectsAnotherSchema() throws {
        XCTAssertThrowsError(try decode(json(replacing: "schema", with: 2)))
    }

    func testRejectsAMissingKey() throws {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: fixtureData()) as? [String: Any])
        object.removeValue(forKey: "backup")
        XCTAssertThrowsError(try decode(JSONSerialization.data(withJSONObject: object)))
    }

    func testRejectsAnUnreadableTime() throws {
        XCTAssertThrowsError(try decode(json(replacing: "generatedAt", with: "yesterday")))
    }

    func testAcceptsANullPart() throws {
        let snapshot = try decode(json(replacing: "machine", with: nil))
        XCTAssertNil(snapshot.machine)
    }

    func testRejectsBlockedQueriesAboveQueriesToday() throws {
        var part = try adBlocker()
        part["queriesToday"] = 10
        part["blockedToday"] = 11
        XCTAssertThrowsError(try decode(json(replacing: "adBlocker", with: part)))
    }

    func testAcceptsBlockedQueriesEqualToQueriesToday() throws {
        var part = try adBlocker()
        part["queriesToday"] = 10
        part["blockedToday"] = 10
        let snapshot = try decode(json(replacing: "adBlocker", with: part))
        XCTAssertEqual(snapshot.adBlocker?.queriesToday, 10)
        XCTAssertEqual(snapshot.adBlocker?.blockedToday, 10)
    }

    private func adBlocker() throws -> [String: Any] {
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: fixtureData()) as? [String: Any])
        return try XCTUnwrap(object["adBlocker"] as? [String: Any])
    }

    func testDescriptionsAndMirrorsRedact() throws {
        let snapshot = try FixtureBook.away(named: "away-live")
        for text in [String(describing: snapshot), String(reflecting: snapshot), dumped(snapshot)] {
            XCTAssertFalse(text.contains("41234"))
            XCTAssertFalse(text.contains("Pi-hole"))
        }
    }

    private func dumped(_ value: some Any) -> String {
        var text = ""
        dump(value, to: &text)
        return text
    }
}
