import XCTest
@testable import StreetPiCore

final class AwayKeySignalTests: XCTestCase {
    /// The health check and the login probe. A 403 here is the away key.
    private static let keyPaths = ["/healthz", "/api/info/login"]

    /// Pi-hole's own calls, and the other services behind the same gateway.
    private static let otherPaths = [
        "/api/auth",
        "/api/stats/summary",
        "/api/dns/blocking",
        "/api/action/gravity",
        "/api/queries",
        "/api/history",
        "/netdata/api/v1/info",
        "/kuma/api/status-page/house",
    ]

    private static let otherStatuses = [200, 302, 401, 404, 429, 500, 502, 503, 520]

    func testA403OnTheHealthCheckOrLoginProbeIsARefusedKey() {
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

    /// Current: the away client labels every 403 a refused key, including these.
    func testAnyOther403IsARefusedKey() {
        for path in Self.otherPaths {
            XCTAssertTrue(AwayKeySignal.isRefusedKey(path: path, status: 403), path)
        }
    }
}
