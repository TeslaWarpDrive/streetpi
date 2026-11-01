import StreetPiCore
@testable import StreetPi

@MainActor
extension DesignSnapshotTests {
    func testDNSDomainsSuccessNotice() {
        assertMatrix(
            section: .group(.adBlockerAndDNS),
            screen: .ready(.healthyFixture),
            testName: "dns-domains-success",
            dnsPage: .domains,
            actionNotice: ActionNotice(
                title: "Domain allowed",
                detail: "example.test is on the allow list.",
                failed: false
            )
        )
    }

    func testDNSQueryLogFailureNotice() {
        assertMatrix(
            section: .group(.adBlockerAndDNS),
            screen: .ready(.healthyFixture),
            testName: "dns-query-log-failure",
            dnsPage: .queryLog,
            actionNotice: ActionNotice(problem: .rateLimited)
        )
    }

    func testDNSUpkeepPendingGravityNotice() {
        assertMatrix(
            section: .group(.adBlockerAndDNS),
            screen: .ready(.healthyFixture),
            testName: "dns-upkeep-pending-gravity",
            dnsPage: .upkeep,
            actionNotice: AwayGravityStep.updating.notice,
            awayLive: true
        )
    }
}
