import SwiftUI
import StreetPiCore

struct ActionConfirm: View {
    var action: HouseholdAction
    var theme: StreetTheme
    var onCancel: () -> Void
    var onConfirm: () -> Void

    private var confirmation: Confirmation {
        ActionPolicy.confirmation(for: action)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        card
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: proxy.size.height)
                }
                .scrollIndicators(.hidden)
                .safeAreaPadding(.bottom, TabClearance.sheet)
            }
        }
        .accessibilityAddTraits(.isModal)
        .accessibilityElement(children: .contain)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: Rhythm.block) {
            words
            VStack(spacing: Rhythm.line) {
                confirmButton
                Button("Cancel", action: onCancel)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(theme.ink)
                    .frame(maxWidth: .infinity)
                    .padding(Rhythm.line)
            }
        }
        .padding(Rhythm.block)
        .frame(maxWidth: 480)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(theme.hairline, lineWidth: 1)
        }
        .padding(Rhythm.page)
    }

    private var words: some View {
        VStack(alignment: .leading, spacing: Rhythm.line) {
            Text("Before this changes")
                .font(.system(.title2, design: .rounded))
                .foregroundStyle(theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(confirmation.explanation ?? "")
                .font(.body)
                .foregroundStyle(theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var confirmButton: some View {
        let title = confirmation.requiresFaceID ? "Confirm with Face ID" : "Confirm"
        return Button(action: onConfirm) {
            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(Rhythm.line)
        }
        .buttonStyle(.plain)
        .foregroundStyle(theme.background)
        .background(theme.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityLabel(title)
    }
}
