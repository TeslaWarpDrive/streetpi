import SnapshotTesting
import StreetPiCore
import SwiftUI
import UIKit
import XCTest
@testable import StreetPi

/// Visual regression coverage on fixtures. This does not replace a simulator gateway walkthrough.
@MainActor
final class AwayLiveSnapshotTests: XCTestCase {
    private let now = Date.streetFixtureNow
    private let house = HouseholdSnapshot.healthyFixture

    func testHomeMode() {
        assertMatrix(testName: "tunnel-home") { size in
            AppShell(section: .home, screen: .ready(house), now: now, onSection: { _ in })
                .styled(size)
        }
    }

    func testAwayLive() {
        var status = StatusNarrator.narrate(house, now: now)
        status.linkLine = AwayCopy.awayChip
        assertMatrix(testName: "tunnel-away-live") { size in
            AppShell(
                section: .home,
                screen: .explained(status, house),
                now: now,
                onSection: { _ in },
                awayLive: true
            )
            .styled(size)
        }
    }

    func testAwayMailbox() throws {
        let board = try FixtureBook.awayBoard()
        let report = try XCTUnwrap(board.snapshot)
        let briefing = try XCTUnwrap(board.status?.briefing)
        assertMatrix(testName: "tunnel-away-mailbox") { size in
            AppShell(
                section: .home,
                screen: .explained(briefing, report),
                now: report.capturedAt.addingTimeInterval(12),
                onSection: { _ in },
                desk: board.desk,
                machine: board.machine,
                piNotice: board.piNotice,
                machineReading: report.machine,
                statusBoard: board.status,
                awayStatus: .reading(generatedAt: report.capturedAt, problem: nil, note: nil)
            )
            .styled(size)
        }
    }

    func testCantReachEitherRoad() {
        assertMatrix(testName: "tunnel-offline") { size in
            AppShell(
                section: .home,
                screen: .ready(house),
                now: now,
                onSection: { _ in },
                awayStatus: .unreachable
            )
            .styled(size)
        }
    }

    func testAwaySettingsMasked() {
        let saved = AwayGatewayForm(address: "https://gateway.example.test", saved: true)
        assertMatrix(testName: "tunnel-settings-away") { size in
            ScrollView {
                AwayGatewaySection(theme: .house, form: saved)
                    .controlPlate(theme: .house)
                    .padding(Rhythm.page)
            }
            .styled(size)
        }
    }

    func testAwaySettingsEmpty() {
        assertMatrix(testName: "tunnel-settings-away-empty") { size in
            ScrollView {
                AwayGatewaySection(theme: .house, form: AwayGatewayForm())
                    .controlPlate(theme: .house)
                    .padding(Rhythm.page)
            }
            .styled(size)
        }
    }

    func testPauseSheet() throws {
        let pause = HouseholdAction.pauseAdBlocking(try XCTUnwrap(PauseLength(seconds: 300)))
        assertMatrix(testName: "tunnel-pause") { size in
            AppShell(
                section: .group(.adBlockerAndDNS),
                screen: .ready(house),
                now: now,
                onSection: { _ in },
                pendingAction: pause,
                awayLive: true
            )
            .styled(size)
        }
    }

    func testGravityNotice() {
        assertMatrix(testName: "tunnel-gravity") { size in
            AppShell(
                section: .group(.adBlockerAndDNS),
                screen: .ready(house),
                now: now,
                onSection: { _ in },
                actionNotice: AwayGravityStep.updating.notice,
                awayLive: true
            )
            .styled(size)
        }
    }

    private func assertMatrix<V: View>(
        testName: String,
        @ViewBuilder content: (SnapshotScale) -> V
    ) {
        for size in SnapshotScale.allCases {
            for device in SnapshotDevice.allCases {
                assertSnapshot(
                    of: content(size),
                    as: .image(
                        drawHierarchyInKeyWindow: true,
                        precision: 0.96,
                        perceptualPrecision: 0.98,
                        layout: .device(config: device.config),
                        traits: UITraitCollection(traitsFrom: [
                            UITraitCollection(userInterfaceStyle: .dark),
                            UITraitCollection(preferredContentSizeCategory: size.category),
                        ])
                    ).standardRange(),
                    named: "dark-\(size.rawValue)-\(device.rawValue)",
                    testName: testName
                )
            }
        }
    }
}

private extension View {
    func styled(_ size: SnapshotScale) -> some View {
        preferredColorScheme(.dark)
            .environment(\.colorScheme, .dark)
            .environment(\.dynamicTypeSize, size.dynamicType)
            .environment(\.streetPiStill, true)
    }
}
