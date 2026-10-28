import AVFoundation
import SnapshotTesting
import StreetPiCore
import SwiftUI
import UIKit
import XCTest
@testable import StreetPi

@MainActor
final class DesignSnapshotTests: XCTestCase {
    private let now = Date.streetFixtureNow
    private let house = HouseholdSnapshot.healthyFixture

    func testHome() {
        assertMatrix(section: .home, screen: .ready(house), testName: "home")
    }

    func testAway() {
        assertMatrix(section: .home, screen: .ready(.awayFreshFixture), testName: "away")
    }

    func testError() {
        assertMatrix(section: .home, screen: .failed, testName: "error")
    }

    func testStale() {
        assertMatrix(section: .home, screen: .ready(.staleFixture), testName: "stale")
    }

    func testEmpty() {
        assertMatrix(section: .home, screen: .empty, testName: "empty")
    }

    func testAdBlocker() {
        assertMatrix(
            section: .group(.adBlockerAndDNS),
            screen: .ready(house),
            testName: "ad-blocker"
        )
    }

    func testDNSToday() {
        assertMatrix(
            section: .group(.adBlockerAndDNS),
            screen: .ready(house),
            testName: "dns-today",
            dnsPage: .today
        )
    }

    func testDNSStatistics() {
        assertMatrix(
            section: .group(.adBlockerAndDNS),
            screen: .ready(house),
            testName: "dns-statistics",
            dnsPage: .statistics
        )
    }

    func testQueryLog() {
        assertMatrix(
            section: .group(.adBlockerAndDNS),
            screen: .ready(house),
            testName: "dns-query-log",
            dnsPage: .queryLog
        )
    }

    func testLiveLog() {
        assertMatrix(
            section: .group(.adBlockerAndDNS),
            screen: .ready(house),
            testName: "dns-live-log",
            dnsPage: .liveLog
        )
    }

    func testDNSServices() {
        assertMatrix(
            section: .group(.adBlockerAndDNS),
            screen: .ready(house),
            testName: "dns-services",
            dnsPage: .services
        )
    }

    func testDNSClients() {
        assertMatrix(
            section: .group(.adBlockerAndDNS),
            screen: .ready(house),
            testName: "dns-clients",
            dnsPage: .clients
        )
    }

    func testDNSGroups() {
        assertMatrix(
            section: .group(.adBlockerAndDNS),
            screen: .ready(house),
            testName: "dns-groups",
            dnsPage: .groups
        )
    }

    func testDNSDomains() {
        assertMatrix(
            section: .group(.adBlockerAndDNS),
            screen: .ready(house),
            testName: "dns-domains",
            dnsPage: .domains
        )
    }

    func testDNSLists() {
        assertMatrix(
            section: .group(.adBlockerAndDNS),
            screen: .ready(house),
            testName: "dns-lists",
            dnsPage: .lists
        )
    }

    func testDNSLocalNames() {
        assertMatrix(
            section: .group(.adBlockerAndDNS),
            screen: .ready(house),
            testName: "dns-local",
            dnsPage: .localNames
        )
    }

    func testDNSUpkeep() {
        assertMatrix(
            section: .group(.adBlockerAndDNS),
            screen: .ready(house),
            testName: "dns-upkeep",
            dnsPage: .upkeep
        )
    }

    func testDNSConfirm() {
        assertMatrix(
            section: .group(.adBlockerAndDNS),
            screen: .ready(house),
            testName: "dns-confirm",
            dnsPage: .today,
            pending: .pauseAdBlocking(.fiveMinutes)
        )
    }

    func testDNSAllow() {
        assertMatrix(
            section: .group(.adBlockerAndDNS),
            screen: .ready(house),
            testName: "dns-allow",
            dnsPage: .queryLog,
            pending: .allowDomain(named: "news.example.test")
        )
    }

    func testDNSSetup() {
        assertMatrix(
            section: .group(.adBlockerAndDNS),
            screen: .ready(house),
            testName: "dns-setup",
            showsSetup: true
        )
    }

    func testDNSRefused() {
        assertMatrix(
            section: .group(.adBlockerAndDNS),
            screen: .ready(house),
            testName: "dns-refused",
            dnsProblem: .refused
        )
    }

    func testMachineDashboard() {
        assertMatrix(section: .group(.piHealth), screen: .ready(house), testName: "machine-dashboard")
    }

    func testMachineChart() {
        assertMatrix(
            section: .group(.piHealth),
            screen: .ready(house),
            testName: "machine-chart",
            machinePage: .chart
        )
    }

    func testMachineServices() {
        assertMatrix(
            section: .group(.piHealth),
            screen: .ready(house),
            testName: "machine-services",
            machinePage: .services
        )
    }

    func testMachineContainers() {
        assertMatrix(
            section: .group(.piHealth),
            screen: .ready(house),
            testName: "machine-containers",
            machinePage: .containers
        )
    }

    func testAlerts() {
        assertMatrix(section: .alerts, screen: .ready(house), testName: "alerts")
    }

    func testSettings() {
        assertMatrix(section: .settings, screen: .ready(house), testName: "settings")
    }

    func testLiveHomeTile() {
        let board = liveBoard
        assertMatrix(
            section: .home,
            screen: .explained(board.status, board.snapshot),
            testName: "live-home-tile",
            desk: board.desk
        )
    }

    func testLiveAdBlocker() {
        let board = liveBoard
        assertMatrix(
            section: .group(.adBlockerAndDNS),
            screen: .explained(board.status, board.snapshot),
            testName: "live-ad-blocker",
            desk: board.desk
        )
    }

    /// The shared overview presented from the Home card.
    func testAdBlockerSheet() {
        assertBlockerSheet(desk: .houseFixture, testName: "ad-blocker-sheet")
    }

    /// Paused: the pills give way to the one way back on.
    func testAdBlockerSheetPaused() {
        var desk = DNSDesk.houseFixture
        desk.blocking = DNSBlocking(enabled: false, pause: .fiveMinutes)
        assertBlockerSheet(desk: desk, testName: "ad-blocker-sheet-paused")
    }

    private func assertBlockerSheet(desk: DNSDesk, testName: String) {
        for size in SnapshotScale.allCases {
            for device in SnapshotDevice.allCases {
                let view = AfterglowScope {
                    AdBlockerOverview(
                        desk: desk,
                        theme: .house,
                        wide: false,
                        onAction: { _ in },
                        onClose: {}
                    )
                }
                .preferredColorScheme(.dark)
                .environment(\.colorScheme, .dark)
                .environment(\.dynamicTypeSize, size.dynamicType)
                .environment(\.streetPiStill, true)
                recordSnapshot(
                    of: view,
                    layout: device.config,
                    size: size,
                    named: "dark-\(size.rawValue)-\(device.rawValue)",
                    testName: testName
                )
            }
        }
    }

    private var liveBoard: AdBlockerBoard {
        var desk = DNSDesk.emptyLookups
        desk.blocking = DNSBlocking(enabled: true)
        desk.day = [DayChartSample(hour: 14, allowed: 9, blocked: 3)]
        desk.spokenLine = LookupFraction.line(stopped: 3, lookups: 12)
        let load = PiholeDeskLoad(desk: desk, total: 12, blocked: 3, blockingEnabled: true)
        return AdBlockerHome.ready(load, now: now)
    }

    func testStatusNotSetUp() {
        assertMatrix(
            section: .home,
            screen: .ready(.emptyFixture),
            testName: "status-not-set-up",
            board: .notSetUp()
        )
    }

    func testStatusReady() {
        assertMatrix(
            section: .home,
            screen: .ready(StatusPageFixture.previewSnapshot(now: now)),
            testName: "status-ready",
            board: StatusPageFixture.previewBoard(now: now)
        )
    }

    func testPiUnreachable() {
        var quiet = house
        quiet.machine = nil
        assertMatrix(
            section: .home,
            screen: .ready(quiet),
            testName: "pi-unreachable",
            piNotice: "The Pi is not answering."
        )
    }

    func testSplashFinal() throws {
        let url = try XCTUnwrap(
            Bundle.main.url(forResource: SplashFilm.posterName, withExtension: "png")
        )
        let image = try XCTUnwrap(UIImage(contentsOfFile: url.path))
        assertSplash(image, testName: "splash-final")
    }

    func testSplashMid() async throws {
        let url = try XCTUnwrap(
            Bundle.main.url(forResource: SplashFilm.videoName, withExtension: "mp4")
        )
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        let (cgImage, _) = try await generator.image(at: CMTime(seconds: 3, preferredTimescale: 600))
        assertSplash(UIImage(cgImage: cgImage), testName: "splash-mid")
    }

    func testComponentGallery() {
        for size in SnapshotScale.allCases {
            for device in SnapshotDevice.allCases {
                let width = device.config.size?.width ?? 320
                let board = AfterglowScope {
                    ComponentBoard()
                }
                .frame(width: width)
                .environment(\.colorScheme, .dark)
                .environment(\.dynamicTypeSize, size.dynamicType)
                .environment(\.streetPiStill, true)
                recordFitting(
                    of: board,
                    size: size,
                    named: "dark-\(size.rawValue)-\(device.rawValue)",
                    testName: "component-gallery"
                )
            }
        }
    }

    private func assertSplash(_ image: UIImage, testName: String) {
        for size in SnapshotScale.allCases {
            for device in SnapshotDevice.allCases {
                let view = LaunchOverlay(frame: image)
                    .preferredColorScheme(.dark)
                    .environment(\.colorScheme, .dark)
                    .environment(\.dynamicTypeSize, size.dynamicType)
                    .environment(\.streetPiStill, true)
                recordSnapshot(
                    of: view,
                    layout: device.config,
                    size: size,
                    named: "dark-\(size.rawValue)-\(device.rawValue)",
                    testName: testName
                )
            }
        }
    }

    private func assertMatrix(
        section: AppSection,
        screen: HouseScreen,
        testName: String,
        dnsPage: DNSPage? = nil,
        desk: DNSDesk = .houseFixture,
        machinePage: MachinePage? = nil,
        pending: HouseholdAction? = nil,
        showsSetup: Bool = false,
        dnsProblem: PiholeProblem? = nil,
        piNotice: String? = nil,
        board: HouseStatusBoard? = nil
    ) {
        for size in SnapshotScale.allCases {
            for device in SnapshotDevice.allCases {
                let view = AppShell(
                    section: section,
                    screen: screen,
                    now: now,
                    onSection: { _ in },
                    desk: desk,
                    dnsPage: dnsPage,
                    machinePage: machinePage,
                    pendingAction: pending,
                    showsSetup: showsSetup,
                    dnsProblem: dnsProblem,
                    piNotice: piNotice,
                    statusBoard: board
                )
                .preferredColorScheme(.dark)
                .environment(\.colorScheme, .dark)
                .environment(\.dynamicTypeSize, size.dynamicType)
                .environment(\.streetPiStill, true)
                recordSnapshot(
                    of: view,
                    layout: device.config,
                    size: size,
                    named: "dark-\(size.rawValue)-\(device.rawValue)",
                    testName: testName
                )
            }
        }
    }

    private func recordSnapshot<V: View>(
        of view: V,
        layout: ViewImageConfig,
        size: SnapshotScale,
        named: String,
        testName: String = #function
    ) {
        assertSnapshot(
            of: view,
            as: .image(
                drawHierarchyInKeyWindow: true,
                // The system tab bar redraws its symbols a little differently each run.
                // The pages above the bar stay put. A moved card still fails this.
                precision: 0.96,
                perceptualPrecision: 0.98,
                layout: .device(config: layout),
                traits: traits(size: size)
            ),
            named: named,
            testName: testName
        )
    }

    /// Full gallery height at the device width. A scroll view would clip the lower components.
    private func recordFitting<V: View>(
        of view: V,
        size: SnapshotScale,
        named: String,
        testName: String
    ) {
        assertSnapshot(
            of: view,
            as: .image(
                perceptualPrecision: 0.98,
                layout: .sizeThatFits,
                traits: traits(size: size)
            ),
            named: named,
            testName: testName
        )
    }

    private func traits(size: SnapshotScale) -> UITraitCollection {
        UITraitCollection(traitsFrom: [
            UITraitCollection(userInterfaceStyle: .dark),
            UITraitCollection(preferredContentSizeCategory: size.category),
        ])
    }
}

enum SnapshotScale: String, CaseIterable {
    case `default`
    case largest

    var dynamicType: DynamicTypeSize {
        switch self {
        case .default: .large
        case .largest: .accessibility5
        }
    }

    var category: UIContentSizeCategory {
        switch self {
        case .default: .large
        case .largest: .accessibilityExtraExtraExtraLarge
        }
    }
}

enum SnapshotDevice: String, CaseIterable {
    case smallPhone
    case largePhone
    case pad
    case padLandscape

    var config: ViewImageConfig {
        switch self {
        case .smallPhone: .iPhoneSe
        case .largePhone: .iPhone13ProMax
        case .pad: .iPadPro11(.portrait)
        case .padLandscape: .iPadPro11(.landscape)
        }
    }
}

extension DesignSnapshotTests {
    func testRoomSmartHome() {
        assertShellMatrix(section: .home, testName: "room-smart-home", initialRoom: .smartHome)
    }

    func testRoomRemoteHelp() {
        assertShellMatrix(section: .home, testName: "room-remote-help", initialRoom: .remoteHelp)
    }

    func testPausedAdBlocker() {
        var desk = DNSDesk.houseFixture
        desk.blocking = DNSBlocking(enabled: false, pause: .fiveMinutes, pauseEndsAt: now.addingTimeInterval(300))
        assertMatrix(section: .group(.adBlockerAndDNS), screen: .ready(house), testName: "dns-paused", desk: desk)
    }

    func testDomainEditor() {
        assertArtifactMatrix(of: DomainEditor(theme: .house, onAction: { _ in }), testName: "domain-editor")
    }

    func testSplashHandoff() throws {
        let image = try XCTUnwrap(SplashFilm.poster())
        assertArtifactMatrix(
            of: LaunchOverlay(frame: image, handoffPreview: true),
            testName: "splash-handoff"
        )
    }

    private func assertArtifactMatrix<V: View>(of content: V, testName: String) {
        for size in SnapshotScale.allCases {
            for device in SnapshotDevice.allCases {
                let view = AfterglowScope { content }
                    .preferredColorScheme(.dark)
                    .environment(\.dynamicTypeSize, size.dynamicType)
                    .environment(\.streetPiStill, true)
                recordSnapshot(
                    of: view,
                    layout: device.config,
                    size: size,
                    named: "dark-\(size.rawValue)-\(device.rawValue)",
                    testName: testName
                )
            }
        }
    }

    func testRoomStreaming() {
        assertShellMatrix(section: .home, testName: "room-streaming", initialRoom: .streaming)
    }

    func testRoomBackups() {
        assertShellMatrix(section: .home, testName: "room-backups", initialRoom: .backups)
    }

    func testRoomInternet() {
        assertShellMatrix(section: .home, testName: "room-internet", initialRoom: .internet)
    }

    /// Fixture alarms only. One has no time, so the row shows the sentence alone.
    func testAlertsList() {
        var desk = MachineDesk.houseFixture
        desk.alerts = [
            HouseAlert(
                id: "fixture-temperature",
                sentence: "Warning. The Pi is hot.",
                tone: .attention,
                raisedAt: now.addingTimeInterval(-40 * 60)
            ),
            HouseAlert(
                id: "fixture-disk",
                sentence: "Critical. The disk is nearly full.",
                tone: .problem,
                raisedAt: now.addingTimeInterval(-3 * 3_600)
            ),
            HouseAlert(
                id: "fixture-cpu",
                sentence: "Warning. The processor is busy.",
                tone: .attention
            ),
        ]
        assertShellMatrix(section: .alerts, testName: "alerts-list", machine: desk)
    }

    /// Same matrix as `assertMatrix`, with a Pi desk and an opened room.
    private func assertShellMatrix(
        section: AppSection,
        testName: String,
        machine: MachineDesk = .houseFixture,
        initialRoom: HouseGroup? = nil
    ) {
        for size in SnapshotScale.allCases {
            for device in SnapshotDevice.allCases {
                let view = AppShell(
                    section: section,
                    screen: .ready(house),
                    now: now,
                    onSection: { _ in },
                    machine: machine,
                    initialRoom: initialRoom
                )
                .preferredColorScheme(.dark)
                .environment(\.colorScheme, .dark)
                .environment(\.dynamicTypeSize, size.dynamicType)
                .environment(\.streetPiStill, true)
                recordSnapshot(
                    of: view,
                    layout: device.config,
                    size: size,
                    named: "dark-\(size.rawValue)-\(device.rawValue)",
                    testName: testName
                )
            }
        }
    }

}
