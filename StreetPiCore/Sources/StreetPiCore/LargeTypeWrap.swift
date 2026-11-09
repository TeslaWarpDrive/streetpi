import Foundation

/// Wrap points for the largest Dynamic Type.
///
/// A zero-width space is not drawn and it is not a hyphen. VoiceOver keeps the
/// original words when the view sets its own label.
public enum LargeTypeWrap {
    /// Offers a wrap after a separator. A space-free token also breaks a run
    /// that is still too long for one line. Words in a sentence stay whole.
    public static func allowingWrap(_ text: String) -> String {
        let spaced = text.contains(where: \.isWhitespace)
        var result = ""
        result.reserveCapacity(text.count + 8)
        var run = 0
        for character in text {
            if isSeparator(character) {
                result.append(character)
                result.append(opportunity)
                run = 0
                continue
            }
            if character.isWhitespace {
                result.append(character)
                run = 0
                continue
            }
            if spaced == false, run == longRun {
                result.append(opportunity)
                run = 0
            }
            result.append(character)
            run += 1
        }
        return result
    }

    /// The characters a person would read. Wrap points are gone.
    public static func visible(_ text: String) -> String {
        text.replacingOccurrences(of: opportunity, with: "")
    }

    private static let opportunity = "\u{200B}"
    /// Longer than an ordinary word, shorter than a fingerprint or a bare host.
    private static let longRun = 16

    private static func isSeparator(_ character: Character) -> Bool {
        switch character {
        case ".", "/", ":", "-", "_":
            true
        default:
            false
        }
    }
}
