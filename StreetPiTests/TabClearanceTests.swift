import SnapshotTesting
import StreetPiCore
import SwiftUI
import UIKit
import XCTest
@testable import StreetPi

/// The phones the tab-bar checks run on. Both small phones: the SE has a home button
/// and no bottom inset, the 13 mini has a home indicator.
enum ClearancePhone: String, CaseIterable {
    case smallPhone
    case miniPhone
    case largePhone

    var config: ViewImageConfig {
        switch self {
        case .smallPhone: .iPhoneSe
        case .miniPhone: .iPhone13Mini
        case .largePhone: .iPhone13ProMax
        }
    }
}

/// Window walks shared by the clearance tests.
@MainActor
class ClearanceCase: XCTestCase {
    fileprivate let now = Date.streetFixtureNow
    fileprivate let house = HouseholdSnapshot.healthyFixture

    fileprivate let tabWords: Set<String> = ["House", "Ad blocker", "Pi", "Settings", "Tab Bar"]

    fileprivate func assertStreamingIsWhole(_ label: UILabel, allowsWrap: Bool) {
        let text = plain(label.text)
        XCTAssertFalse(text.contains("-"), "Streaming is hyphenated: \(text)")
        XCTAssertTrue(text.contains("Streaming"), "Title lost letters: \(text)")
        let font = label.font ?? UIFont.preferredFont(forTextStyle: .subheadline)
        let word = ("Streaming" as NSString).size(withAttributes: [.font: font]).width
        let line = font.lineHeight
        if label.bounds.width + 1 < word {
            XCTAssertTrue(allowsWrap, "Streaming wrapped at the default text size")
            XCTAssertGreaterThan(
                label.bounds.height,
                line * 1.4,
                "Streaming is narrower than the word on one line"
            )
            let needed = label.sizeThatFits(CGSize(width: label.bounds.width, height: 10_000)).height
            XCTAssertGreaterThanOrEqual(label.bounds.height + 1, needed, "Streaming is clipped")
        } else {
            XCTAssertGreaterThanOrEqual(label.bounds.width + 1, word)
        }
    }

    fileprivate func assertFullyDrawn(_ label: UILabel) {
        let needed = label.sizeThatFits(CGSize(width: max(label.bounds.width, 1), height: 10_000))
        XCTAssertGreaterThanOrEqual(
            label.bounds.height + 1,
            needed.height,
            "\(plain(label.text)) is clipped"
        )
    }

    /// Exactly one system tab bar, and none of our own strips.
    fileprivate func assertOneTabBar(in window: UIWindow, _ context: String) {
        let bars = systemTabBars(in: window)
        XCTAssertEqual(bars.count, 1, "\(context): expected one tab bar, saw \(bars.count)")
        XCTAssertTrue(
            views(named: "phone-tab-strip", in: window).isEmpty,
            "\(context): a second tab strip is on screen"
        )
    }

    /// Every piece of page text that is on screen sits above the bar, and the last one is on screen.
    /// Call after `scrollToEnd`, so the final row of the page is the one being checked.
    fileprivate func assertPageEndsAboveBar(in window: UIWindow, _ context: String) {
        guard let bar = tabBarFrame(in: window) else {
            XCTFail("\(context): no tab bar")
            return
        }
        let shownArea = pageArea(in: window)
        let texts = pageTexts(in: window).filter { item in
            let shown = item.frame.intersection(shownArea)
            return shown.isNull == false && shown.height > 1 && shown.width > 1
        }
        guard let last = texts.max(by: { $0.frame.maxY < $1.frame.maxY }) else {
            XCTFail("\(context): no page text was found")
            return
        }
        XCTAssertLessThanOrEqual(
            last.frame.maxY,
            bar.minY + 0.5,
            "\(context): the last line \"\(last.text)\" ends at \(last.frame.maxY), "
                + "under the tab bar at \(bar.minY)"
        )
        for item in texts {
            let overlap = item.frame.intersection(bar)
            XCTAssertTrue(
                overlap.isNull || overlap.height < 1,
                "\(context): \"\(item.text)\" sits under the tab bar"
            )
        }
    }

    /// A known final label must be fully visible, even if the scroll view chose the wrong end.
    fileprivate func assertFinalLabel(_ expected: String, in window: UIWindow, _ context: String) {
        guard let bar = tabBarFrame(in: window) else {
            XCTFail("\(context): no tab bar")
            return
        }
        let matches = textFrames(in: window).filter { $0.text.contains(expected) }
        guard let last = matches.min(by: { $0.frame.height < $1.frame.height }) else {
            XCTFail("\(context): final label is missing: \(expected)")
            return
        }
        let area = pageArea(in: window).intersection(window.bounds)
        XCTAssertGreaterThan(last.frame.height, 1, "\(context): final label has no height")
        XCTAssertGreaterThanOrEqual(last.frame.minY, area.minY - 0.5, "\(context): final label starts off screen")
        XCTAssertLessThanOrEqual(last.frame.maxY, min(area.maxY, bar.minY) + 0.5,
                                 "\(context): final label is below the visible page: \(expected)")
        XCTAssertGreaterThanOrEqual(last.frame.minX, area.minX - 0.5, "\(context): final label starts outside page")
        XCTAssertLessThanOrEqual(last.frame.maxX, area.maxX + 0.5, "\(context): final label ends outside page")
    }

    fileprivate func assertVisibleTextDoesNotOverlap(in window: UIWindow, _ context: String) {
        let area = pageArea(in: window)
        var leaves: [(text: String, frame: CGRect)] = []
        for item in pageTexts(in: window) {
            let shown = item.frame.intersection(area)
            let leaf = shown.width > 2 && shown.height > 2 && shown.height < 72
            let narrow = shown.width < window.bounds.width * 0.92
            guard leaf, narrow else { continue }
            leaves.append((item.text, shown))
        }
        for index in leaves.indices {
            for other in leaves.indices.dropFirst(index + 1) {
                let left = leaves[index]
                let right = leaves[other]
                if covers(left.frame, right.frame) || covers(right.frame, left.frame) { continue }
                let overlap = left.frame.intersection(right.frame)
                guard overlap.width > 3, overlap.height > 3 else { continue }
                XCTFail("\(context): \(left.text) overlaps \(right.text)")
            }
        }
    }

    fileprivate func covers(_ outer: CGRect, _ inner: CGRect) -> Bool {
        outer.insetBy(dx: -2, dy: -2).contains(inner)
    }

    /// The part of the window the page draws into. It includes the strip behind the tab bar,
    /// so text that slid under the bar still counts.
    fileprivate func pageArea(in window: UIWindow) -> CGRect {
        guard let scroll = mainScroll(in: window) else { return window.bounds }
        return scroll.convert(scroll.bounds, to: window).intersection(window.bounds)
    }

    fileprivate func label(_ identifier: String, in window: UIWindow) -> UILabel? {
        labels(in: window).first {
            $0.accessibilityIdentifier == identifier && $0.bounds.width > 2 && $0.bounds.height > 2
        }
    }

    fileprivate func host(
        page: AppSection,
        scale: SnapshotScale,
        config: ViewImageConfig,
        status: HouseStatusBoard? = nil,
        snapshot: HouseholdSnapshot? = nil
    ) -> UIWindow {
        let root = AppShell(
            section: page,
            screen: .ready(snapshot ?? house),
            now: now,
            onSection: { _ in },
            statusBoard: status
        )
        .preferredColorScheme(.dark)
        .environment(\.colorScheme, .dark)
        .environment(\.dynamicTypeSize, scale.dynamicType)
        .environment(\.streetPiStill, true)
        let controller = UIHostingController(rootView: root)
        controller.overrideUserInterfaceStyle = .dark
        controller.traitOverrides.preferredContentSizeCategory = scale.category
        controller.traitOverrides.userInterfaceStyle = .dark
        controller.traitOverrides.horizontalSizeClass = config.traits.horizontalSizeClass
        controller.traitOverrides.verticalSizeClass = config.traits.verticalSizeClass
        let size = config.size ?? CGSize(width: 375, height: 667)
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

    fileprivate func streamingLabel(in window: UIWindow) -> UILabel? {
        labels(in: window).first { plain($0.text).contains("Streaming") }
    }

    fileprivate func labelTexts(in window: UIWindow) -> [String] {
        labels(in: window).map { plain($0.text) }.filter { $0.isEmpty == false }
    }

    fileprivate func labels(in view: UIView) -> [UILabel] {
        var found: [UILabel] = []
        if let label = view as? UILabel {
            found.append(label)
        }
        for child in view.subviews {
            found.append(contentsOf: labels(in: child))
        }
        return found
    }

    fileprivate func scrollToEnd(_ window: UIWindow) {
        guard let scroll = mainScroll(in: window) else { return }
        let bottom = scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom
        scroll.setContentOffset(CGPoint(x: 0, y: max(-scroll.adjustedContentInset.top, bottom)), animated: false)
        scroll.layoutIfNeeded()
        pump()
    }

    /// Scrolls the page the way a person would until the frame is fully above the bar.
    fileprivate func scrollIntoView(_ view: UIView, in window: UIWindow) {
        guard let scroll = mainScroll(in: window) else { return }
        let rect = view.convert(view.bounds, to: scroll).insetBy(dx: 0, dy: -8)
        scroll.scrollRectToVisible(rect, animated: false)
        scroll.layoutIfNeeded()
        pump()
    }

    fileprivate func mainScroll(in window: UIWindow) -> UIScrollView? {
        allScrolls(in: window)
            .filter { $0.bounds.height > window.bounds.height * 0.4 }
            .max { $0.bounds.width * $0.bounds.height < $1.bounds.width * $1.bounds.height }
    }

    fileprivate func tabBarFrame(in window: UIWindow) -> CGRect? {
        guard let bar = systemTabBars(in: window).first else { return nil }
        return bar.convert(bar.bounds, to: window)
    }

    fileprivate func systemTabBars(in view: UIView) -> [UITabBar] {
        let shown = view.isHidden == false && view.alpha > 0.01 && view.bounds.height > 1
        guard shown else { return [] }
        if let bar = view as? UITabBar {
            return [bar]
        }
        return view.subviews.flatMap { systemTabBars(in: $0) }
    }

    fileprivate func views(named name: String, in view: UIView) -> [UIView] {
        var found: [UIView] = []
        if view.accessibilityIdentifier == name {
            found.append(view)
        }
        for child in view.subviews {
            found.append(contentsOf: views(named: name, in: child))
        }
        return found
    }

    /// Text and spoken labels on the page, not in the tab bar, and not whole-screen containers.
    fileprivate func pageTexts(in window: UIWindow) -> [(text: String, frame: CGRect)] {
        textFrames(in: window).filter { item in
            tabWords.contains(item.text) == false
                && item.frame.height < window.bounds.height * 0.6
                && item.frame.width > 1
        }
    }

    fileprivate func textFrames(in window: UIWindow) -> [(text: String, frame: CGRect)] {
        var found: [(text: String, frame: CGRect)] = []
        collectText(in: window, window: window, into: &found)
        return found
    }

    fileprivate func collectText(in view: UIView, window: UIWindow, into found: inout [(text: String, frame: CGRect)]) {
        if view is UITabBar || view.isHidden || view.alpha < 0.01 { return }
        if let label = view as? UILabel {
            let text = plain(label.text)
            if text.isEmpty == false {
                found.append((text, label.convert(label.bounds, to: window)))
            }
        }
        let spoken = plain(view.accessibilityLabel)
        if spoken.isEmpty == false {
            found.append((spoken, view.convert(view.bounds, to: window)))
        }
        if let elements = view.accessibilityElements {
            for case let element as NSObject in elements {
                let text = plain(element.accessibilityLabel)
                if text.isEmpty { continue }
                let frame = window.convert(element.accessibilityFrame, from: nil)
                found.append((text, frame))
            }
        }
        for child in view.subviews {
            collectText(in: child, window: window, into: &found)
        }
    }

    fileprivate func plain(_ text: String?) -> String {
        (text ?? "").replacingOccurrences(of: "\u{2060}", with: "")
    }

    fileprivate func pump() {
        for _ in 0..<6 {
            RunLoop.current.run(until: Date().addingTimeInterval(0.02))
        }
    }

    fileprivate func allScrolls(in view: UIView) -> [UIScrollView] {
        var found: [UIScrollView] = []
        if let scroll = view as? UIScrollView {
            found.append(scroll)
        }
        for child in view.subviews {
            found.append(contentsOf: allScrolls(in: child))
        }
        return found
    }

    fileprivate func image(of window: UIWindow) -> UIImage {
        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        return renderer.image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
    }
}

/// Fails when a tab's last row ends under the tab bar, when a second bar appears,
/// or when two pieces of text overlap.
@MainActor
final class TabClearanceTests: ClearanceCase {
    private let tabs: [(name: String, section: AppSection, finalLabel: String)] = [
        ("house", .home, "Tap a tile to open it. Hold the ad blocker to pause it."),
        ("ad-blocker", .group(.adBlockerAndDNS), DNSPage.upkeep.blurb),
        ("pi", .group(.piHealth), MachinePage.containers.blurb),
        ("settings", .settings, "Save status page"),
    ]

    /// Every tab, scrolled to its end, on the small phones and a large one at both text sizes.
    /// Each end state is also kept as an image, so the last row can be looked at.
    func testEveryTabEndsAboveTheTabBar() {
        for phone in ClearancePhone.allCases {
            for scale in SnapshotScale.allCases {
                for tab in tabs {
                    let context = "\(tab.name) \(scale.rawValue) \(phone.rawValue)"
                    let window = host(page: tab.section, scale: scale, config: phone.config)
                    assertOneTabBar(in: window, context)
                    assertVisibleTextDoesNotOverlap(in: window, context)
                    scrollToEnd(window)
                    assertFinalLabel(tab.finalLabel, in: window, context)
                    assertPageEndsAboveBar(in: window, context)
                    assertVisibleTextDoesNotOverlap(in: window, context)
                    assertSnapshot(
                        of: image(of: window),
                        as: .image(precision: 0.95, perceptualPrecision: 0.5),
                        named: "\(tab.name)-dark-\(scale.rawValue)-\(phone.rawValue)",
                        testName: "tabEnd"
                    )
                    window.isHidden = true
                }
            }
        }
    }

    /// The iPad opens on the sidebar. No tab bar sits along the bottom of the page.
    func testPadHasNoBottomBar() {
        for scale in SnapshotScale.allCases {
            let window = host(page: .home, scale: scale, config: SnapshotDevice.pad.config)
            if let bar = tabBarFrame(in: window) {
                XCTAssertLessThan(
                    bar.maxY,
                    window.bounds.height * 0.5,
                    "The iPad shows a tab bar along the bottom at \(scale.rawValue)"
                )
            }
            window.isHidden = true
        }
    }

    func testStreamingTitleStaysWhole() {
        for scale in SnapshotScale.allCases {
            let window = host(page: .home, scale: scale, config: ClearancePhone.smallPhone.config)
            guard let label = streamingLabel(in: window) else {
                XCTFail("Streaming is not in the view. Saw: \(labelTexts(in: window).joined(separator: " | "))")
                window.isHidden = true
                continue
            }
            scrollIntoView(label, in: window)
            assertStreamingIsWhole(label, allowsWrap: scale == .largest)
            if let bar = tabBarFrame(in: window) {
                let frame = label.convert(label.bounds, to: window)
                XCTAssertLessThanOrEqual(frame.maxY, bar.minY + 0.5, "Streaming is not above the tab bar")
            } else {
                XCTFail("No tab bar")
            }
            window.isHidden = true
        }
    }

    /// The status word and the checked line stay apart, and the checked line is fully drawn.
    func testStatusWordClearsTheCheckedLine() {
        let configs: [(String, ViewImageConfig)] = [
            ("smallPhone", ClearancePhone.smallPhone.config),
            ("largePhone", ClearancePhone.largePhone.config),
            ("pad", SnapshotDevice.pad.config),
        ]
        for (name, config) in configs {
            for scale in SnapshotScale.allCases {
                let context = "\(name) \(scale.rawValue)"
                let window = host(page: .home, scale: scale, config: config)
                guard let checked = label("checked-line", in: window) else {
                    XCTFail("\(context): the checked line is missing")
                    window.isHidden = true
                    continue
                }
                XCTAssertTrue(plain(checked.text).contains("just now"), "Checked line lost its words")
                assertFullyDrawn(checked)
                let checkedFrame = checked.convert(checked.bounds, to: window)
                let status = pageTexts(in: window).first { $0.text.contains("good") && $0.text.count < 40 }
                if let status {
                    let overlap = status.frame.intersection(checkedFrame)
                    XCTAssertTrue(
                        overlap.isNull || overlap.width < 1 || overlap.height < 1,
                        "\(context): the status word overlaps the checked line"
                    )
                } else {
                    XCTFail("\(context): the status word is missing")
                }
                if let plainLine = label("blocker-plain", in: window) {
                    assertFullyDrawn(plainLine)
                } else {
                    XCTFail("\(context): the ad blocker line is missing")
                }
                window.isHidden = true
            }
        }
    }

    /// The fixture Home paints the monitor count, not the sample backup sentence.
    func testSamplePhrasesStayOffTheHomeCards() {
        let window = host(page: .home, scale: .default, config: ClearancePhone.smallPhone.config)
        let spoken = textFrames(in: window).map(\.text).joined(separator: " ")
        XCTAssertTrue(spoken.contains("8 of 8 up"), spoken)
        XCTAssertFalse(spoken.contains("The weekly copy succeeded."), spoken)
        XCTAssertFalse(spoken.contains("All answering"), spoken)
        XCTAssertTrue(spoken.contains("About 1 in 5 things"), spoken)
        XCTAssertTrue(spoken.contains("using the Pi"), spoken)
        window.isHidden = true
    }

    /// The installed Home paints the status page, not the 8-service sample.
    func testStatusPageReplacesTheSample() {
        let board = StatusPageFixture.previewBoard(now: now)
        let window = host(
            page: .home,
            scale: .default,
            config: SnapshotDevice.pad.config,
            status: board,
            snapshot: StatusPageFixture.previewSnapshot(now: now)
        )
        let spoken = textFrames(in: window).map(\.text).joined(separator: " ")
        XCTAssertFalse(spoken.contains("8 of 8"))
        XCTAssertFalse(spoken.contains("The weekly copy succeeded."))
        XCTAssertTrue(spoken.contains("27 of 28"), spoken)
        XCTAssertTrue(spoken.contains("check-in"), spoken)
        XCTAssertTrue(spoken.contains("up to date"), spoken)
        window.isHidden = true
    }
}
