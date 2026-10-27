import SnapshotTesting
import StreetPiCore
import SwiftUI
import UIKit
import XCTest
@testable import StreetPi

/// Window walks shared by the clearance tests.
@MainActor
class ClearanceCase: XCTestCase {
    fileprivate let now = Date.streetFixtureNow
    fileprivate let house = HouseholdSnapshot.healthyFixture

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

    fileprivate func assertCheckedLineIsWhole(in window: UIWindow) {
        let label = requireLabel("checked-line", in: window)
        XCTAssertTrue(plain(label.text).contains("just now"), "Checked line lost its words: \(plain(label.text))")
        assertFullyDrawn(label)
        let frame = label.convert(label.bounds, to: window)
        let bar = tabBarFrame(in: window)
        XCTAssertTrue(visibleClears(frame, bar: bar, in: window), "Checked just now sits under the tab bar")
    }

    fileprivate func assertAccentClearsCheckedLine(in window: UIWindow) {
        guard let accent = find("status-accent", in: window),
              let checked = label("checked-line", in: window) else {
            XCTFail("The status word or the checked line is missing")
            return
        }
        let accentFrame = accent.convert(accent.bounds, to: window)
        let checkedFrame = checked.convert(checked.bounds, to: window)
        let overlap = accentFrame.intersection(checkedFrame)
        XCTAssertTrue(
            overlap.isNull || overlap.width < 1 || overlap.height < 1,
            "The status word overlaps the checked line"
        )
    }

    fileprivate func assertFullyDrawn(_ label: UILabel) {
        let needed = label.sizeThatFits(CGSize(width: max(label.bounds.width, 1), height: 10_000))
        XCTAssertGreaterThanOrEqual(
            label.bounds.height + 1,
            needed.height,
            "\(plain(label.text)) is clipped"
        )
    }

    fileprivate func assertVisibleTextClearsBar(in window: UIWindow) {
        let bar = tabBarFrame(in: window)
        var texts = textFrames(in: window)
        if texts.isEmpty {
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            CATransaction.flush()
            window.layoutIfNeeded()
            pump()
            texts = textFrames(in: window)
        }
        if texts.isEmpty {
            // Ad blocker, Pi, and Settings draw with SwiftUI, so they have no UILabel.
            // The rendered rows just above the one strip still have to be clear of type.
            assertRenderedInkClearsBar(bar, in: window)
            return
        }
        let visible = visiblePage(in: window)
        let tabWords: Set<String> = ["House", "Ad blocker", "Pi", "Settings", "Tabs"]
        for item in texts where tabWords.contains(item.text) == false {
            let shown = item.frame.intersection(visible)
            let coversWindow = shown.height > window.bounds.height * 0.9
                && shown.width > window.bounds.width * 0.9
            guard shown.height > 1, coversWindow == false else { continue }
            let overlap = shown.intersection(bar)
            XCTAssertTrue(
                overlap.isNull || overlap.height < 1,
                "\(item.text) sits under the tab bar"
            )
        }
    }

    /// The eight points above the strip stay free of type. A clipped caption fails this.
    fileprivate func assertRenderedInkClearsBar(_ bar: CGRect, in window: UIWindow) {
        let format = UIGraphicsImageRendererFormat()
        format.scale = max(window.traitCollection.displayScale, 1)
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(bounds: window.bounds, format: format)
        let image = renderer.image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        guard let cg = image.cgImage else {
            XCTFail("The page did not draw")
            return
        }
        let width = cg.width
        let height = cg.height
        // Draw into a known 8-bit buffer. The renderer’s own bitmap is not always 32-bit.
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = pixels.withUnsafeMutableBytes { raw -> Bool in
            guard let ctx = CGContext(
                data: raw.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            ctx.translateBy(x: 0, y: CGFloat(height))
            ctx.scaleBy(x: 1, y: -1)
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else {
            XCTFail("The page image has no color")
            return
        }
        let scale = window.bounds.width > 0 ? CGFloat(width) / window.bounds.width : image.scale
        let gap = Int((8 * scale).rounded())
        let barTop = Int((bar.minY * scale).rounded())
        let start = max(0, barTop - gap)
        let end = min(height, barTop)
        guard end > start, bar.height > 20, bar.height < window.bounds.height * 0.4 else {
            XCTFail("The tab strip could not be measured. \(viewOutline(window))")
            return
        }
        let x0 = min(width - 1, Int((16 * scale).rounded()))
        let x1 = max(x0 + 1, width - x0)
        func sample(_ x: Int, _ y: Int) -> Int {
            let index = (y * width + x) * 4
            return max(Int(pixels[index]), Int(pixels[index + 1]), Int(pixels[index + 2]))
        }
        var brightest = 0
        for y in start..<end {
            var bright = 0
            var x = x0
            while x < x1 {
                if sample(x, y) > 150 {
                    bright += 1
                }
                x += 1
            }
            brightest = max(brightest, bright)
        }
        XCTAssertLessThan(
            brightest,
            8,
            "Type still sits on the tab bar"
        )
        var pageInk = 0
        let pageEnd = start
        let pageStart = max(0, pageEnd - Int((80 * scale).rounded()))
        for y in pageStart..<pageEnd {
            var x = x0
            while x < x1 {
                if sample(x, y) > 150 {
                    pageInk += 1
                }
                x += 1
            }
        }
        XCTAssertGreaterThan(pageInk, 20, "The page above the tab bar did not draw")
    }

    fileprivate func assertVisibleTextDoesNotOverlap(in window: UIWindow) {
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

    fileprivate func covers(_ outer: CGRect, _ inner: CGRect) -> Bool {
        outer.insetBy(dx: -2, dy: -2).contains(inner)
    }

    fileprivate func clears(_ frame: CGRect, bar: CGRect, in window: UIWindow) -> Bool {
        let shown = frame.intersection(visiblePage(in: window))
        guard shown.height > 1 else { return false }
        let overlap = shown.intersection(bar)
        return overlap.isNull || overlap.height < 1
    }

    /// A line that is still below the fold is not under the bar. The part on screen must clear it.
    fileprivate func visibleClears(_ frame: CGRect, bar: CGRect, in window: UIWindow) -> Bool {
        let shown = frame.intersection(visiblePage(in: window))
        guard shown.height > 1 else { return true }
        let overlap = shown.intersection(bar)
        return overlap.isNull || overlap.height < 1
    }

    fileprivate func visiblePage(in window: UIWindow) -> CGRect {
        guard let scroll = mainScroll(in: window) else { return window.bounds }
        let inset = scroll.bounds.inset(by: scroll.adjustedContentInset)
        return scroll.convert(inset, to: window)
    }

    fileprivate func requireLabel(_ identifier: String, in window: UIWindow) -> UILabel {
        guard let label = label(identifier, in: window) else {
            XCTFail("\(identifier) is not in the view. Saw: \(labelTexts(in: window).joined(separator: " | "))")
            return UILabel()
        }
        return label
    }

    fileprivate func label(_ identifier: String, in window: UIWindow) -> UILabel? {
        labels(in: window).first {
            $0.accessibilityIdentifier == identifier && $0.bounds.width > 2 && $0.bounds.height > 2
        }
    }

    fileprivate func find(_ name: String, in view: UIView) -> UIView? {
        if view.accessibilityIdentifier == name, view.bounds.width > 2, view.bounds.height > 2 {
            return view
        }
        for child in view.subviews {
            if let found = find(name, in: child) { return found }
        }
        return nil
    }

    fileprivate func host(
        page: AppSection,
        scale: SnapshotScale,
        device: SnapshotDevice,
        pinStreaming: Bool = false,
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
        .environment(\.pinsStreamingTitle, pinStreaming)
        let controller = UIHostingController(rootView: root)
        controller.overrideUserInterfaceStyle = .dark
        controller.traitOverrides.preferredContentSizeCategory = scale.category
        controller.traitOverrides.userInterfaceStyle = .dark
        let size = device.config.size ?? CGSize(width: 320, height: 568)
        controller.view.frame = CGRect(origin: .zero, size: size)
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = controller
        window.overrideUserInterfaceStyle = .dark
        window.makeKeyAndVisible()
        controller.beginAppearanceTransition(true, animated: false)
        controller.endAppearanceTransition()
        // Ad blocker, Pi, and Settings are not inside the system tab bar, so their
        // labels show up on a later layout turn than House.
        for _ in 0..<4 {
            CATransaction.flush()
            window.layoutIfNeeded()
            controller.view.layoutIfNeeded()
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            pump()
        }
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
        scroll.setContentOffset(CGPoint(x: 0, y: max(0, bottom)), animated: false)
        scroll.layoutIfNeeded()
        pump()
    }

    fileprivate func mainScroll(in window: UIWindow) -> UIScrollView? {
        allScrolls(in: window)
            .filter { $0.contentSize.height > $0.bounds.height + 20 }
            .max { $0.contentSize.height < $1.contentSize.height }
    }

    fileprivate func tabBarFrame(in window: UIWindow) -> CGRect {
        if let bar = systemTabBar(in: window) {
            let frame = bar.convert(bar.bounds, to: window)
            if frame.height > 1, frame.height < window.bounds.height * 0.5 {
                return frame
            }
        }
        let frames = views(named: "phone-tab-strip", in: window).map {
            $0.convert($0.bounds, to: window)
        }.filter { frame in
            frame.width > 1 && frame.height > 1 && frame.height < window.bounds.height * 0.8
        }
        if let frame = frames.max(by: { $0.width * $0.height < $1.width * $1.height }) {
            return frame
        }
        let reservedHeight = min(max(TabClearance.phoneBar, 49), window.bounds.height)
        return CGRect(
            x: 0,
            y: window.bounds.height - reservedHeight,
            width: window.bounds.width,
            height: reservedHeight
        )
    }

    fileprivate func systemTabBar(in view: UIView) -> UIView? {
        let shown = view.isHidden == false && view.alpha > 0.01 && view.bounds.height > 1
        if view is UITabBar, shown {
            return view
        }
        for child in view.subviews {
            if let found = systemTabBar(in: child) {
                return found
            }
        }
        return nil
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

    fileprivate func viewOutline(_ view: UIView, depth: Int = 0) -> String {
        guard depth < 8 else { return "" }
        let name = String(describing: type(of: view))
        let line = String(repeating: " ", count: depth) + "\(name) \(Int(view.bounds.width))x\(Int(view.bounds.height))"
        let children = view.subviews.prefix(6).map { viewOutline($0, depth: depth + 1) }
        return ([line] + children).joined(separator: " | ")
    }

    fileprivate func textFrames(in window: UIWindow) -> [(text: String, frame: CGRect)] {
        var found: [(text: String, frame: CGRect)] = []
        collectText(in: window, window: window, into: &found)
        if found.isEmpty {
            materializeAccessibility(window)
            collectText(in: window, window: window, into: &found)
        }
        return found
    }

    /// Pages outside the system tab bar do not install UILabel until accessibility is asked.
    fileprivate func materializeAccessibility(_ view: UIView) {
        let count = view.accessibilityElementCount()
        if count > 0 {
            for index in 0..<count {
                _ = view.accessibilityElement(at: index)
            }
        }
        for child in view.subviews {
            materializeAccessibility(child)
        }
    }

    fileprivate func collectText(in view: UIView, window: UIWindow, into found: inout [(text: String, frame: CGRect)]) {
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
}

/// Fails when type sits under the tab bar, or when two pieces of text overlap.
@MainActor
final class TabClearanceTests: ClearanceCase {
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
            window.isHidden = true
        }
    }

    /// The status word and the checked line stay apart, and the checked line is fully drawn.
    func testStatusWordClearsTheCheckedLine() {
        let devices: [SnapshotDevice] = [.smallPhone, .largePhone, .pad]
        for device in devices {
            for scale in SnapshotScale.allCases {
                let window = host(page: .home, scale: scale, device: device)
                assertCheckedLineIsWhole(in: window)
                assertAccentClearsCheckedLine(in: window)
                if device != .pad {
                    assertVisibleTextClearsBar(in: window)
                    let plain = requireLabel("blocker-plain", in: window)
                    assertFullyDrawn(plain)
                    let frame = plain.convert(plain.bounds, to: window)
                    XCTAssertTrue(
                        visibleClears(frame, bar: tabBarFrame(in: window), in: window),
                        "The ad blocker line sits under the tab bar"
                    )
                }
                window.isHidden = true
            }
        }
    }

    /// The fixture Home does not paint the sample count or the sample backup sentence.
    func testSamplePhrasesStayOffTheHomeCards() {
        let window = host(page: .home, scale: .default, device: .smallPhone)
        let spoken = textFrames(in: window).map(\.text).joined(separator: " ")
        XCTAssertFalse(spoken.contains("8 of 8"), spoken)
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
            device: .pad,
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

    /// Small-phone shots at both text sizes. Recording is on until the new references land.
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
            .environment(\.pinsStreamingTitle, false)
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

}
