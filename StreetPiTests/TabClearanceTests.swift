import SnapshotTesting
import StreetPiCore
import SwiftUI
import UIKit
import XCTest
@testable import StreetPi

/// Fails when type or a card is laid out under the tab bar. A changed picture is not the check.
@MainActor
final class TabClearanceTests: XCTestCase {
    private let now = Date.streetFixtureNow
    private let house = HouseholdSnapshot.healthyFixture

    func testVisibleTextClearsTheTabBar() {
        let pages: [AppSection] = [.home, .group(.adBlockerAndDNS), .group(.piHealth), .settings]
        for device in [SnapshotDevice.smallPhone, .largePhone] {
            for scale in SnapshotScale.allCases {
                for page in pages {
                    let window = host(page: page, scale: scale, device: device)
                    assertVisibleTextClearsBar(in: window)
                    scrollToEnd(window)
                    assertVisibleTextClearsBar(in: window)
                    window.isHidden = true
                }
            }
        }
    }

    func testStreamingTitleStaysWhole() {
        for scale in SnapshotScale.allCases {
            let window = host(page: .home, scale: scale, device: .smallPhone)
            reveal(["Streaming", "last 24 hours"], in: window)
            assertStreamingIsWhole(in: window)
            assertVisibleTextClearsBar(in: window)
            let image = draw(window)
            let name = "dark-\(scale.rawValue)-smallPhone"
            withSnapshotTesting(record: .failed) {
                assertSnapshot(
                    of: image,
                    as: .image(precision: 0.95, perceptualPrecision: 0.5),
                    named: name,
                    testName: "home-clear"
                )
            }
            window.isHidden = true
        }
    }

    private func assertStreamingIsWhole(in window: UIWindow) {
        let title = contentLabels(in: window).first { plain($0.text) == "Streaming" }
        guard let title else {
            XCTFail("Streaming is not on screen")
            return
        }
        let font = title.font ?? UIFont.preferredFont(forTextStyle: .subheadline)
        let word = ("Streaming" as NSString).size(withAttributes: [.font: font]).width
        XCTAssertGreaterThanOrEqual(
            title.bounds.width + 1,
            word,
            "Streaming is narrower than the word, so it will hyphenate or clip"
        )
        XCTAssertFalse(plain(title.text).contains("-"))
    }

    private func assertVisibleTextClearsBar(in window: UIWindow) {
        let bar = tabBarFrame(in: window)
        let tabWords: Set<String> = ["House", "Ad blocker", "Pi", "Settings"]
        for label in contentLabels(in: window) {
            let text = plain(label.text)
            if text.isEmpty || tabWords.contains(text) { continue }
            let frame = label.convert(label.bounds, to: window)
            guard window.bounds.intersects(frame), frame.height > 1, frame.width > 1 else { continue }
            let overlap = frame.intersection(bar)
            XCTAssertTrue(
                overlap.isNull || overlap.height < 1,
                "\(text) sits under the tab bar"
            )
        }
    }

    private func host(page: AppSection, scale: SnapshotScale, device: SnapshotDevice) -> UIWindow {
        let root = AppShell(
            section: page,
            screen: .ready(house),
            now: now,
            onSection: { _ in }
        )
        .preferredColorScheme(.dark)
        .environment(\.colorScheme, .dark)
        .environment(\.dynamicTypeSize, scale.dynamicType)
        .environment(\.streetPiStill, true)
        let controller = UIHostingController(rootView: root)
        controller.overrideUserInterfaceStyle = .dark
        controller.traitOverrides.preferredContentSizeCategory = scale.category
        controller.traitOverrides.userInterfaceStyle = .dark
        let size = device.config.size ?? CGSize(width: 320, height: 568)
        controller.view.bounds = CGRect(origin: .zero, size: size)
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = controller
        window.overrideUserInterfaceStyle = .dark
        window.makeKeyAndVisible()
        pump()
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        pump()
        return window
    }

    private func reveal(_ words: [String], in window: UIWindow) {
        guard let scroll = mainScroll(in: window) else { return }
        let marks = contentLabels(in: window).filter { label in
            let text = plain(label.text)
            return words.contains { text.contains($0) }
        }
        let tops = marks.map { $0.convert($0.bounds, to: scroll).minY }
        guard let top = tops.min() else { return }
        let offset = max(0, top - 8)
        scroll.setContentOffset(CGPoint(x: 0, y: offset), animated: false)
        scroll.layoutIfNeeded()
        pump()
    }

    private func scrollToEnd(_ window: UIWindow) {
        guard let scroll = mainScroll(in: window) else { return }
        let bottom = scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom
        scroll.setContentOffset(CGPoint(x: 0, y: max(0, bottom)), animated: false)
        scroll.layoutIfNeeded()
        pump()
    }

    private func mainScroll(in window: UIWindow) -> UIScrollView? {
        allScrolls(in: window)
            .filter { $0.contentSize.height > $0.bounds.height + 20 }
            .max { $0.contentSize.height < $1.contentSize.height }
    }

    private func tabBarFrame(in window: UIWindow) -> CGRect {
        let reservedHeight = min(TabClearance.phoneBar, window.bounds.height)
        let reserved = CGRect(
            x: 0,
            y: window.bounds.height - reservedHeight,
            width: window.bounds.width,
            height: reservedHeight
        )
        let titles: Set<String> = ["House", "Ad blocker", "Pi", "Settings"]
        let labels = contentLabels(in: window).filter { titles.contains(plain($0.text)) }
        guard labels.count >= 3 else { return reserved }
        let top = labels.map { $0.convert($0.bounds, to: window).minY }.min() ?? reserved.minY
        let barTop = min(reserved.minY, max(0, top - 12))
        return CGRect(x: 0, y: barTop, width: window.bounds.width, height: window.bounds.height - barTop)
    }

    private func draw(_ window: UIWindow) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = window.screen.scale
        let renderer = UIGraphicsImageRenderer(bounds: window.bounds, format: format)
        return renderer.image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
    }

    private func plain(_ text: String?) -> String {
        (text ?? "").replacingOccurrences(of: "\u{2060}", with: "")
    }

    private func pump() {
        for _ in 0..<6 {
            RunLoop.current.run(until: Date().addingTimeInterval(0.02))
        }
    }

    private func contentLabels(in view: UIView) -> [UILabel] {
        var found: [UILabel] = []
        if let label = view as? UILabel {
            found.append(label)
        }
        for child in view.subviews {
            found.append(contentsOf: contentLabels(in: child))
        }
        return found
    }

    private func allScrolls(in view: UIView) -> [UIScrollView] {
        var found: [UIScrollView] = []
        if let scroll = view as? UIScrollView {
            found.append(scroll)
        }
        for child in view.subviews {
            found.append(contentsOf: allScrolls(in: child))
        }
        return found
    }
}
