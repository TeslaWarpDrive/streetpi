import XCTest
@testable import StreetPiCore

final class AwayKeySignalTests: XCTestCase {
    /// The health check, the login probe, and the other services behind the gateway.
    /// A 403 here is the away key. Pi-hole's own calls are not in this list.
    private static let keyPaths = [
        "/healthz",
        "/api/info/login",
        "/netdata",
        "/netdata/api/v1/info",
        "/netdata/api/v1/data",
        "/kuma",
        "/kuma/api/status-page/house",
        "/kuma/api/status-page/heartbeat/house",
    ]

    /// Pi-hole's own calls. A 403 here is the Pi saying no.
    private static let otherPaths = [
        "/api/auth",
        "/api/stats/summary",
        "/api/dns/blocking",
        "/api/action/gravity",
        "/api/queries",
        "/api/history",
        "/api/netdata",
        "/api/kuma",
        "/netdata-cloud/api/v1/info",
    ]

    private static let otherStatuses = [200, 302, 401, 404, 429, 500, 502, 503, 520]

    func testA403OnTheHealthCheckLoginProbeNetdataOrKumaIsARefusedKey() {
        for path in Self.keyPaths {
            XCTAssertTrue(AwayKeySignal.isRefusedKey(path: path, status: 403), path)
        }
    }

    func testAnyStatusOtherThan403IsNotARefusedKey() {
        for path in Self.keyPaths + Self.otherPaths {
            for status in Self.otherStatuses {
                XCTAssertFalse(
                    AwayKeySignal.isRefusedKey(path: path, status: status),
                    "\(path) \(status)"
                )
            }
        }
    }

    func testAnyOther403IsNotARefusedKey() {
        for path in Self.otherPaths {
            XCTAssertFalse(AwayKeySignal.isRefusedKey(path: path, status: 403), path)
        }
    }
}

final class AwayKeyLatchTests: XCTestCase {
    func testARefusedKeyStaysUntilRefreshTakesIt() {
        let latch = AwayKeyLatch()
        latch.note(path: "/healthz", status: 403)
        latch.note(path: "/api/stats/summary", status: 403)
        XCTAssertTrue(latch.take())
        XCTAssertFalse(latch.take())
    }

    func testNetdataAndKuma403sStayOnTheSharedLatch() {
        let latch = AwayKeyLatch()
        latch.note(path: "/netdata/api/v1/info", status: 403)
        XCTAssertTrue(latch.take())
        latch.note(path: "/kuma/api/status-page/house", status: 403)
        XCTAssertTrue(latch.take())
        latch.note(path: "/api/auth", status: 403)
        XCTAssertFalse(latch.take())
    }
}

final class LiveRoadAgreementTests: XCTestCase {
    func testTheLaterPiholeCallDecidesWhetherTheLiveRoadIsUp() {
        let rows: [(Int?, Int?, Bool)] = [
            (200, 200, true),
            (403, 200, true),
            (500, 200, true),
            (nil, 200, true),
            (200, 403, false),
            (200, nil, false),
            (200, 401, false),
            (200, 500, false),
            (403, 403, false),
            (403, nil, false),
            (nil, nil, false),
        ]
        for (health, pihole, up) in rows {
            XCTAssertEqual(
                LiveRoadAgreement.isUp(healthStatus: health, piholeStatus: pihole),
                up,
                "health \(String(describing: health)) pihole \(String(describing: pihole))"
            )
        }
    }

    func testALaterPihole200ClearsAHealth403() {
        XCTAssertFalse(LiveRoadAgreement.refusedKey(healthStatus: 403, piholeStatus: 200))
        XCTAssertTrue(LiveRoadAgreement.refusedKey(healthStatus: 200, piholeStatus: 403))
        XCTAssertTrue(LiveRoadAgreement.refusedKey(healthStatus: 403, piholeStatus: nil))
        XCTAssertTrue(LiveRoadAgreement.refusedKey(healthStatus: 403, piholeStatus: 403))
        XCTAssertFalse(LiveRoadAgreement.refusedKey(healthStatus: 200, piholeStatus: nil))
        XCTAssertFalse(LiveRoadAgreement.refusedKey(healthStatus: 200, piholeStatus: 500))
        XCTAssertFalse(LiveRoadAgreement.refusedKey(healthStatus: nil, piholeStatus: 200))
    }
}
