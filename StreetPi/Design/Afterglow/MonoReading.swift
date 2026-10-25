import SwiftUI

struct MonoReading: View {
    var text: String
    var emphasize: Bool = false

    @Environment(\.afterglowPalette) private var palette
    @Environment(\.afterglowGate) private var gate

    var body: some View {
        reading
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var reading: some View {
        let line = Text(text)
            .font(emphasize ? AfterglowType.reading : AfterglowType.metadata)
            .foregroundStyle(emphasize ? palette.ink : palette.secondary)
        if gate.holdsMotion {
            line
                .contentTransition(.numericText())
                .animation(AfterglowMotion.spring, value: text)
        } else {
            line
        }
    }
}
