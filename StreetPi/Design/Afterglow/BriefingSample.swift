import SwiftUI

struct BriefingSample: View {
    @Environment(\.afterglowPalette) private var palette
    @Environment(\.afterglowGate) private var gate
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: AfterglowShape.line) {
            header
            StatusHeadline(title: "Everything's good.", accentWord: "good", tone: .calm)
            GlassPanel(showsGlint: true) {
                VStack(alignment: .leading, spacing: AfterglowShape.line) {
                    ComposeText(lines: [
                        "Blocking is on.",
                        "The Pi is answering.",
                        "Backups copied on Sunday.",
                    ])
                    MonoReading(text: "Updated just now")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var header: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: AfterglowShape.line) {
                    heading
                    refresh
                }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: AfterglowShape.line) {
                        heading
                        Spacer(minLength: AfterglowShape.line)
                        refresh
                    }
                    VStack(alignment: .leading, spacing: AfterglowShape.line) {
                        heading
                        refresh
                    }
                }
            }
        }
    }

    private var refresh: some View {
        AfterglowButton(title: "Check again", systemImage: "arrow.clockwise", action: checkAgain)
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: AfterglowShape.tight) {
            KickerLabel(text: "StreetPi")
            HStack(alignment: .center, spacing: AfterglowShape.tight) {
                StatusDot(tone: .calm)
                Text("Home network")
                    .font(AfterglowType.metadata)
                    .foregroundStyle(palette.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                statusMark
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Home network, all good")
        }
    }

    @ViewBuilder
    private var statusMark: some View {
        if gate.holdsMotion {
            Image(systemName: AfterglowSymbol.status(.calm))
                .font(.footnote)
                .foregroundStyle(palette.calm)
                .symbolEffect(.bounce, value: "calm")
                .accessibilityHidden(true)
        } else {
            Image(systemName: AfterglowSymbol.status(.calm))
                .font(.footnote)
                .foregroundStyle(palette.calm)
                .accessibilityHidden(true)
        }
    }

    private func checkAgain() {}
}
