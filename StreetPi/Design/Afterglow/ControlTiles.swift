import SwiftUI

/// Compact Aurora tiles: a big lavender figure and a plain-English line.
struct ControlScreen<Content: View>: View {
    var wide: Bool
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Rhythm.line) {
                content()
            }
            .padding(.horizontal, Rhythm.page)
            .padding(.top, Rhythm.line)
            // The last line on a small phone fills the page at the largest text size.
            // A taller tail pushes the top of that line off the screen.
            .padding(.bottom, Rhythm.tight)
            .frame(maxWidth: wide ? 880 : 560)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
    }
}

struct ControlTitle: View {
    var title: String
    var line: String
    var theme: StreetTheme

    var body: some View {
        VStack(alignment: .leading, spacing: Rhythm.tight) {
            Text(title)
                .font(.system(.largeTitle, design: .rounded))
                .foregroundStyle(theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(line)
                .font(.body)
                .foregroundStyle(theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ControlSection: View {
    var title: String
    var theme: StreetTheme

    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(theme.ink)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

/// One column at the largest text sizes, so figures wrap instead of colliding.
struct ControlGrid<Content: View>: View {
    var maximumColumns: Int = 2
    @ViewBuilder var content: () -> Content

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: Rhythm.line) {
                content()
            }
        } else {
            AfterglowTileGrid(
                spacing: Rhythm.line,
                minimumColumnWidth: 96,
                maximumColumns: maximumColumns
            ) {
                content()
            }
        }
    }
}

struct NumberTile: View {
    var label: String
    var number: String
    var line: String
    var theme: StreetTheme

    var body: some View {
        VStack(alignment: .leading, spacing: Rhythm.tight) {
            WrappingLine(text: label, font: .subheadline, color: theme.secondary)
            WrappingLine(text: number, font: .system(.largeTitle, design: .rounded), color: theme.accent)
            WrappingLine(text: line, font: .subheadline, color: theme.ink)
        }
        .controlPlate(theme: theme)
        .accessibilityElement(children: .combine)
    }
}

struct PlainTile: View {
    var title: String
    var line: String
    var theme: StreetTheme

    var body: some View {
        VStack(alignment: .leading, spacing: Rhythm.tight) {
            WrappingLine(text: title, font: .headline, color: theme.ink)
            WrappingLine(text: line, font: .subheadline, color: theme.secondary)
        }
        .controlPlate(theme: theme)
        .accessibilityElement(children: .combine)
    }
}

struct LinkTile: View {
    var title: String
    var line: String
    var symbol: String
    var theme: StreetTheme
    var finalLineLayout: String?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: Rhythm.line) {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(theme.accent)
                    .frame(width: 28, alignment: .leading)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Rhythm.tight) {
                    WrappingLine(text: title, font: .headline, color: theme.ink)
                    WrappingLine(text: line, font: .subheadline, color: theme.secondary)
                        .reportsLayout(finalLineLayout)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .controlPlate(theme: theme)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title). \(line)")
    }
}

extension View {
    func controlPlate(theme: StreetTheme) -> some View {
        modifier(ControlPlateModifier(theme: theme))
    }
}

/// Lets long names break after a dot so large text stays inside the tile.
private struct WrappingLine: View {
    var text: String
    var font: Font
    var color: Color

    var body: some View {
        Text(text.replacingOccurrences(of: ".", with: ".\u{200B}"))
            .font(font)
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct ControlPlateModifier: ViewModifier {
    var theme: StreetTheme

    func body(content: Content) -> some View {
        content
            .padding(Rhythm.line)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(theme.hairline, lineWidth: 1)
            }
    }
}
