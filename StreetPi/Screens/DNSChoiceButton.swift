import SwiftUI

struct DNSChoiceButton: View {
    var title: String
    var label: String
    var theme: StreetTheme
    var enabled: Bool = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.body.bold())
                .foregroundStyle(enabled ? theme.ink : theme.tertiary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Rhythm.line)
                .frame(minHeight: 44, alignment: .leading)
                .background(theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(theme.hairline, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .disabled(enabled == false)
        .accessibilityLabel(label)
    }
}
