import SnapshotTesting
import StreetPiCore
import SwiftUI
import UIKit
import XCTest
@testable import StreetPi

/// Fails when type sits under the tab bar, or when two pieces of text overlap.
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
                    assertVisibleTextDoesNotOverlap(in: window)
                    scrollToEnd(window)
                    assertVisibleTextClearsBar(in: window)
                    assertVisibleTextDoesNotOverlap(in: window)
                    window.isHidden = true
                }
            }
        }
    }

    func testStreamingTitleStaysWhole() {
        for scale in SnapshotScale.allCases {
            let window = host(page: .home, scale: scale, device: .smallPhone, pinStreaming: true)
            guard let label = streamingLabel(in: window) else {
                XCTFail("Streaming is not in the view. Saw: \(labelTexts(in: window).joined(separator: " | "))")
                window.isHidden = true
                continue
            }
            assertStreamingIsWhole(label, allowsWrap: scale == .largest)
            assertVisibleTextClearsBar(in: window)
            assertVisibleTextDoesNotOverlap(in: window)
            let bar = tabBarFrame(in: window)
            let streamingFrame = label.convert(label.bounds, to: window)
            XCTAssertTrue(clears(streamingFrame, bar: bar, in: window), "Streaming is not above the tab bar")
            if let percent = percentLineFrame(in: window) {
                XCTAssertTrue(clears(percent, bar: bar, in: window), "The percent line is not above the tab bar")
            } else if scale == .default {
                XCTFail("The percent line is not in the view")
            }
            window.isHidden = true
        }
    }

    /// Scrolled small-phone shots. The suite records them so a person can see both fixes.
    func testHomeClearProof() {
        for scale in SnapshotScale.allCases {
            let view = AppShell(
                section: .home,
                screen: .ready(house),
                now: now,
                onSection: { _ in }
            )
            .preferredColorScheme(.dark)
            .environment(\.colorScheme, .dark)
            .environment(\.dynamicTypeSize, scale.dynamicType)
            .environment(\.streetPiStill, true)
            .environment(\.pinsStreamingTitle, true)
            let traits = UITraitCollection(traitsFrom: [
                UITraitCollection(userInterfaceStyle: .dark),
                UITraitCollection(preferredContentSizeCategory: scale.category),
            ])
            withSnapshotTesting(record: .never) {
                assertSnapshot(
                    of: view,
                    as: .wait(
                        for: 0.2,
                        on: .image(
                            drawHierarchyInKeyWindow: true,
                            precision: 0.95,
                            perceptualPrecision: 0.5,
                            layout: .device(config: SnapshotDevice.smallPhone.config),
                            traits: traits
                        )
                    ),
                    named: "dark-\(scale.rawValue)-smallPhone",
                    testName: "homeClear"
                )
            }
        }
    }

    /// The percent text's container. The one-point mark can sit apart from the glyphs.
    private func percentLineFrame(in window: UIWindow) -> CGRect? {
        guard let mark = view(named: "blocker-fraction", in: window) else { return nil }
        var current: UIView? = mark.superview
        while let view = current {
            let frame = view.convert(view.bounds, to: window)
            if frame.width > 8, frame.height > 8, frame.height < 160 {
                return frame
            }
            current = view.superview
        }
        return nil
    }

    private func view(named name: String, in view: UIView) -> UIView? {
        if view.accessibilityIdentifier == name { return view }
        for child in view.subviews {
            if let found = self.view(named: name, in: child) { return found }
        }
        return nil
    }

    private func assertStreamingIsWhole(_ label: UILabel, allowsWrap: Bool) {
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

    private func assertVisibleTextClearsBar(in window: UIWindow) {
        let bar = tabBarFrame(in: window)
        let texts = textFrames(in: window)
        XCTAssertFalse(texts.isEmpty, "No text was found to compare with the tab bar")
        let visible = visiblePage(in: window)
        let tabWords: Set<String> = ["House", "Ad blocker", "Pi", "Settings"]
        for item in texts where tabWords.contains(item.text) == false {
            let shown = item.frame.intersection(visible)
            let shortEnough = shown.height > 1 && shown.height < window.bounds.height * 0.85
            guard shortEnough else { continue }
            let overlap = shown.intersection(bar)
            XCTAssertTrue(
                overlap.isNull || overlap.height < 1,
                "\(item.text) sits under the tab bar"
            )
        }
    }

    private func assertVisibleTextDoesNotOverlap(in window: UIWindow) {
        let visible = visiblePage(in: window)
        let tabWords: Set<String> = ["House", "Ad blocker", "Pi", "Settings"]
        var leaves: [(text: String, frame: CGRect)] = []
        for item in textFrames(in: window) where tabWords.contains(item.text) == false {
            let shown = item.frame.intersection(visible)
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
                XCTFail("\(left.text) overlaps \(right.text)")
            }
        }
    }

    private func covers(_ outer: CGRect, _ inner: CGRect) -> Bool {
        outer.insetBy(dx: -2, dy: -2).contains(inner)
    }

    private func clears(_ frame: CGRect, bar: CGRect, in window: UIWindow) -> Bool {
        let shown = frame.intersection(visiblePage(in: window))
        guard shown.height > 1 else { return false }
        let overlap = shown.intersection(bar)
        return overlap.isNull || overlap.height < 1
    }

    private func visiblePage(in window: UIWindow) -> CGRect {
        guard let scroll = mainScroll(in: window) else { return window.bounds }
        let inset = scroll.bounds.inset(by: scroll.adjustedContentInset)
        return scroll.convert(inset, to: window)
    }

    private func host(
        page: AppSection,
        scale: SnapshotScale,
        device: SnapshotDevice,
        pinStreaming: Bool = false
    ) -> UIWindow {
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
        .environment(\.pinsStreamingTitle, pinStreaming)
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

    private func streamingLabel(in window: UIWindow) -> UILabel? {
        labels(in: window).first { plain($0.text).contains("Streaming") }
    }

    private func labelTexts(in window: UIWindow) -> [String] {
        labels(in: window).map { plain($0.text) }.filter { $0.isEmpty == false }
    }

    private func labels(in view: UIView) -> [UILabel] {
        var found: [UILabel] = []
        if let label = view as? UILabel {
            found.append(label)
        }
        for child in view.subviews {
            found.append(contentsOf: labels(in: child))
        }
        return found
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
        let reservedHeight = min(max(TabClearance.phoneBar, 56), window.bounds.height)
        let reserved = CGRect(
            x: 0,
            y: window.bounds.height - reservedHeight,
            width: window.bounds.width,
            height: reservedHeight
        )
        let titles: Set<String> = ["House", "Ad blocker", "Pi", "Settings"]
        let labels = textFrames(in: window).filter { titles.contains($0.text) }
        guard labels.count >= 3 else { return reserved }
        let top = labels.map(\.frame.minY).min() ?? reserved.minY
        let barTop = min(reserved.minY, max(0, top - 28))
        return CGRect(x: 0, y: barTop, width: window.bounds.width, height: window.bounds.height - barTop)
    }

    private func textFrames(in window: UIWindow) -> [(text: String, frame: CGRect)] {
        var found: [(text: String, frame: CGRect)] = []
        collectText(in: window, window: window, into: &found)
        return found
    }

    private func collectText(in view: UIView, window: UIWindow, into found: inout [(text: String, frame: CGRect)]) {
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

    private func plain(_ text: String?) -> String {
        (text ?? "").replacingOccurrences(of: "\u{2060}", with: "")
    }

    private func pump() {
        for _ in 0..<6 {
            RunLoop.current.run(until: Date().addingTimeInterval(0.02))
        }
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
