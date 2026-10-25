import StreetPiCore
import SwiftUI

/// One service at a glance. The word sits with the dot.
struct ServiceSquareTile: View {
    var square: ServiceSquare
    var compresses: Bool = false
    var onOpen: () -> Void

    @Environment(\.afterglowPalette) private var palette

    var body: some View {
        Button(action: onOpen) {
            VStack(spacing: AfterglowShape.tight) {
                StatusDot(tone: square.tone)
                Text(square.word)
                    .font(.headline)
                    .foregroundStyle(palette.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(WholeWord.locked(square.title))
                    .font(.subheadline)
                    .foregroundStyle(palette.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: true, vertical: true)
            }
            .padding(AfterglowShape.line)
            .frame(maxWidth: compresses ? .infinity : nil, minHeight: 96)
            .fixedSize(horizontal: compresses == false, vertical: false)
            .background(palette.panel, in: RoundedRectangle(cornerRadius: AfterglowShape.tile, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AfterglowShape.tile, style: .continuous)
                    .strokeBorder(palette.hairline, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(square.title), \(square.word)")
    }
}

/// A title that must not break in the middle of the word, as in "Stream-ing".
enum WholeWord {
    static func locked(_ word: String) -> String {
        word.map(String.init).joined(separator: "\u{2060}")
    }
}
