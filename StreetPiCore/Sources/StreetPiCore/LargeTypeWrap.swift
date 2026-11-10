import Foundation

/// Wrap points for the largest Dynamic Type.
///
/// A separator stays with the word before it, then a zero-width space offers a
/// break, so "example." is not split. A word joiner inside a run that fits
/// stops Text from hyphenating that run. A run the row cannot hold may break
/// between characters, and it never gains a hyphen.
public enum LargeTypeWrap {
    /// `runFits` is true when that whole run, including a trailing separator, fits on the row.
    /// The default keeps every run whole, because a wide row may be able to hold it.
    public static func allowingWrap(
        _ text: String,
        runFits: (String) -> Bool = { _ in true }
    ) -> String {
        var result = ""
        result.reserveCapacity(text.count * 2)
        var run = ""
        func flush() {
            guard run.isEmpty == false else { return }
            result.append(contentsOf: rendered(run, fits: runFits(run)))
            run = ""
        }
        for character in text {
            if character.isWhitespace {
                flush()
                result.append(character)
                continue
            }
            run.append(character)
            if isSeparator(character) {
                flush()
            }
        }
        flush()
        return result
    }

    /// The characters a person would read. Wrap points are gone.
    public static func visible(_ text: String) -> String {
        text.replacingOccurrences(of: opportunity, with: "")
            .replacingOccurrences(of: joiner, with: "")
    }

    private static let opportunity = "\u{200B}"
    private static let joiner = "\u{2060}"

    private static func isSeparator(_ character: Character) -> Bool {
        switch character {
        case ".", "/", ":", "-", "_":
            true
        default:
            false
        }
    }

    /// A fitting run is glued so a line cannot break inside it. The break sits after the dot.
    private static func rendered(_ run: String, fits: Bool) -> String {
        guard fits else {
            var broken = ""
            broken.reserveCapacity(run.count * 2)
            for character in run {
                broken.append(character)
                broken.append(opportunity)
            }
            return broken
        }
        var glued = ""
        glued.reserveCapacity(run.count * 2 + 1)
        var started = false
        for character in run {
            if started {
                glued.append(joiner)
            }
            glued.append(character)
            started = true
        }
        if let last = run.last, isSeparator(last) {
            glued.append(opportunity)
        }
        return glued
    }
}
