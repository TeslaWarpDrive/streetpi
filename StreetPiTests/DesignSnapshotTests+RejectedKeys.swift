import SnapshotTesting
import StreetPiCore
import SwiftUI
import UIKit
import XCTest
@testable import StreetPi

@MainActor
extension DesignSnapshotTests {
    func testRejectedAwayKeyBoard() {
        assertRejectedKey(section: .group(.adBlockerAndDNS))
    }

    func testRejectedAwayKeySettings() {
        assertRejectedKey(section: .settings)
    }

    func testRejectedAwayKeyMailboxBoard() throws {
        try assertRejectedMailbox(section: .group(.adBlockerAndDNS))
    }

    func testRejectedAwayKeyMailboxSettings() throws {
        try assertRejectedMailbox(section: .settings)
    }

    func testRejectedAwayKeyMailboxProblemSettings() throws {
        try assertRejectedMailbox(section: .settings, problem: .wrongAddress)
    }

    func testAwayKeySavedConfirmation() {
        assertKeyDraft(AwayKeyDraft(saved: true))
    }

    func testAwayKeyDraftAfterNoticeClears() {
        assertKeyDraft(AwayKeyDraft(clientID: "FAKE_client.access", secret: "cfast_FAKE_not_a_real_secret"))
    }

    private func assertRejectedKey(section: AppSection, testName: String = #function) {
        let board = AdBlockerHome.offline(now: .streetFixtureNow)
        assertRejectedMatrix(testName: testName) {
            AppShell(
                section: section, screen: .explained(board.status, board.snapshot), now: .streetFixtureNow,
                onSection: { _ in }, desk: board.desk, dnsProblem: .offline, awayStatus: .unreachable,
                gatewayForm: AwayGatewayForm(address: "https://gateway.example.test", saved: true)
            )
            .modifier(AwayKeyNotice(rejected: true, section: section, hasAwayCard: true))
        }
    }

    private func assertRejectedMailbox(
        section: AppSection, problem: MailboxProblem? = nil, testName: String = #function
    ) throws {
        let board = try FixtureBook.awayBoard()
        let report = try XCTUnwrap(board.snapshot)
        let briefing = try XCTUnwrap(board.status?.briefing)
        assertRejectedMatrix(testName: testName) {
            AppShell(
                section: section, screen: .explained(briefing, report), now: report.capturedAt.addingTimeInterval(12),
                onSection: { _ in }, desk: board.desk, machine: board.machine, piNotice: board.piNotice,
                machineReading: report.machine, statusBoard: board.status,
                awayStatus: .reading(generatedAt: report.capturedAt, problem: problem, note: nil),
                gatewayForm: AwayGatewayForm(address: "https://gateway.example.test", saved: true)
            )
            .modifier(AwayKeyNotice(rejected: true, section: section, hasAwayCard: true))
        }
    }

    /// A draft only starts inside Settings, so these draw the page itself, with no rejection on it.
    private func assertKeyDraft(_ draft: AwayKeyDraft, testName: String = #function) {
        assertRejectedMatrix(testName: testName) {
            SettingsView(
                theme: .house, piHost: .constant(""), hostNote: nil, onCommitHost: {},
                gatewayForm: AwayGatewayForm(address: "https://gateway.example.test", saved: true),
                keyDraft: draft
            )
            .background { StreetTheme.house.background.ignoresSafeArea() }
        }
    }

    private func assertRejectedMatrix<V: View>(testName: String, @ViewBuilder content: () -> V) {
        for size in SnapshotScale.allCases {
            for device in SnapshotDevice.allCases {
                let view = content()
                    .preferredColorScheme(.dark)
                    .environment(\.colorScheme, .dark)
                    .environment(\.dynamicTypeSize, size.dynamicType)
                    .environment(\.streetPiStill, true)
                assertSnapshot(
                    of: view,
                    as: .image(
                        drawHierarchyInKeyWindow: true, precision: 0.96, perceptualPrecision: 0.98,
                        layout: .device(config: device.config),
                        traits: UITraitCollection(traitsFrom: [
                            UITraitCollection(userInterfaceStyle: .dark),
                            UITraitCollection(preferredContentSizeCategory: size.category),
                        ])
                    ).standardRange(),
                    named: "dark-\(size.rawValue)-\(device.rawValue)", testName: testName
                )
            }
        }
    }
}
