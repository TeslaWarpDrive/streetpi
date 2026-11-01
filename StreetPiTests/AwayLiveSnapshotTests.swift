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
        assertSettingsMatrix(testName: "tunnel-settings-away", replacingKey: false)
    }

    func testAwaySettingsReplacingKey() {
        assertSettingsMatrix(testName: "tunnel-settings-away-replace", replacingKey: true)
    }

    private func assertSettingsMatrix(testName: String, replacingKey: Bool) {
        let saved = AwayGatewayForm(address: "https://gateway.example.test", saved: true)
        for size in SnapshotScale.allCases {
            for device in SnapshotDevice.allCases {
                let section = AwayGatewaySection(theme: .house, form: saved, replacingKey: replacingKey)
                    .controlPlate(theme: .house)
                    .padding(Rhythm.page)
                // At the largest text size, capture the full form at each device's width.
                // A viewport snapshot hides the credential fields below the introduction.
                let view = VStack(spacing: 0) {
                    if size == .largest {
                        section.frame(width: device.config.size?.width ?? 320)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        ScrollView { section }
                    }
                }
                .styled(size)
                assertSnapshot(
                    of: view,
                    as: .image(
                        drawHierarchyInKeyWindow: true,
                        precision: 0.96,
                        perceptualPrecision: 0.98,
                        layout: size == .largest ? .sizeThatFits : .device(config: device.config),
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

    func testReplaceKeyShowsEmptyFieldsAndWritesOverTheSavedKey() throws {
        XCTAssertFalse(AwayKeyReplace.showsFields(saved: true, replacing: false))
        XCTAssertTrue(AwayKeyReplace.showsFields(saved: true, replacing: true))
        XCTAssertTrue(AwayKeyReplace.showsFields(saved: false, replacing: false))
        XCTAssertFalse(AwayKeyReplace.canSave(replacing: true, clientID: "", secret: "cfast_FAKE_new"))
        XCTAssertFalse(AwayKeyReplace.canSave(replacing: true, clientID: "new.access", secret: " "))
        XCTAssertTrue(AwayKeyReplace.canSave(replacing: true, clientID: "new.access", secret: "cfast_FAKE_new"))
        XCTAssertTrue(AwayKeyReplace.canSave(replacing: false, clientID: "", secret: ""))

        let suite = "streetpi.tests.replace-key"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        let secrets = MemorySecretStore()
        let store = AwayGatewayStore(store: secrets, defaults: defaults)
        let saved = "cfast_FAKE_saved"
        let replaced = "cfast_FAKE_replaced"
        XCTAssertEqual(
            store.save(address: "https://gateway.example.test", clientID: "saved.access", secret: saved),
            .saved
        )
        XCTAssertEqual(
            store.save(address: "https://gateway.example.test", clientID: "replaced.access", secret: replaced),
            .saved
        )
        let loaded = try XCTUnwrap(store.load())
        XCTAssertEqual(loaded.clientID, "replaced.access")
        XCTAssertEqual(loaded.clientSecret, replaced)
        XCTAssertNotEqual(loaded.clientSecret, saved)
        let stored = try XCTUnwrap(secrets.load(for: AwayGatewaySettings.account))
        let payload = try XCTUnwrap(String(bytes: stored, encoding: .utf8))
        XCTAssertTrue(payload.contains(replaced))
        XCTAssertFalse(payload.contains(saved))
        XCTAssertFalse(defaults.dictionaryRepresentation().description.contains(replaced))
        XCTAssertFalse(defaults.dictionaryRepresentation().description.contains(saved))
        store.seedIfNeeded(from: AwayGatewaySettings(
            url: "https://seed.example.test",
            clientID: "seed.access",
            clientSecret: "cfast_FAKE_seed"
        ))
        XCTAssertEqual(store.load()?.clientSecret, replaced)
        XCTAssertEqual(store.load()?.clientID, "replaced.access")
        defaults.removePersistentDomain(forName: suite)
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
