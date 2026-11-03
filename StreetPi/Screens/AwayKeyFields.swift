import SwiftUI

/// The two away-key entries, for a stack to lay out with its own spacing. A secret field's prompt can't
/// wrap, so accessibility text moves the secret's name to a line above it. VoiceOver keeps the field's label.
/// `fill` is the plate behind each entry: the page's surface, or the ground when the fields sit on a card.
struct AwayKeyFields: View {
    var theme: StreetTheme
    var fill: Color
    @Binding var clientID: String
    @Binding var secret: String

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        TextField(
            "Client id",
            text: $clientID,
            prompt: Text("Client id").foregroundStyle(theme.tertiary),
            axis: .vertical
        )
        .modifier(AwayFieldPlate(theme: theme, fill: fill))
        .accessibilityLabel("Client id")
        if dynamicTypeSize.isAccessibilitySize {
            Text("Client secret")
                .font(.body)
                .foregroundStyle(theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(true)
        }
        SecureField(
            "Client secret",
            text: $secret,
            prompt: Text(dynamicTypeSize.isAccessibilitySize ? "" : "Client secret").foregroundStyle(theme.tertiary)
        )
        .modifier(AwayFieldPlate(theme: theme, fill: fill))
        .accessibilityLabel("Client secret")
    }
}

/// The look of an away entry, also used by the gateway address above the key.
struct AwayFieldPlate: ViewModifier {
    var theme: StreetTheme
    var fill: Color

    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .font(.body)
            .foregroundStyle(theme.ink)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            .padding(Rhythm.line)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(fill)
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(theme.hairline, lineWidth: 1)
                    }
            }
    }
}
