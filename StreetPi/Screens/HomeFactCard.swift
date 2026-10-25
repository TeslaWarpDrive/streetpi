import StreetPiCore
import SwiftUI

struct HomeFactCard: View {
    var title: String
    var value: String
    var line: String
    var spoken: String
    var action: (() -> Void)?

    var body: some View {
        if let action {
            Button(action: action) {
                HomeFactFace(title: title, value: value, line: line)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(spoken)
        } else {
            HomeFactFace(title: title, value: value, line: line)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(spoken)
        }
    }
}

private struct HomeFactFace: View {
    var title: String
    var value: String
    var line: String

    @Environment(\.afterglowPalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: AfterglowShape.line) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(palette.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(value)
                .font(.largeTitle.bold())
                .foregroundStyle(palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(line)
                .font(.body)
                .foregroundStyle(palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(AfterglowShape.tilePadding)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .background(palette.panelRaised, in: RoundedRectangle(cornerRadius: AfterglowShape.panel, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AfterglowShape.panel, style: .continuous)
                .strokeBorder(palette.hairline, lineWidth: 1)
        }
    }
}
