import StreetPiCore
import SwiftUI

struct DomainEditor: View {
    var theme: StreetTheme
    var onAction: (HouseholdAction) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var draft = ""
    @State private var blocked = true

    private var name: String { draft.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            ControlScreen(wide: false) {
                ControlTitle(
                    title: "One domain name",
                    line: "This applies to everyone in the house. You will confirm before anything changes.",
                    theme: theme
                )
                TextField("example.test", text: $draft, axis: .vertical)
                    .font(.body.monospaced())
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .padding(Rhythm.line)
                    .controlPlate(theme: theme)
                    .accessibilityLabel("Domain name")
                choice
                Button(blocked ? "Review blocking this name" : "Review allowing this name", action: submit)
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .buttonStyle(.borderedProminent)
                    .disabled(name.isEmpty)
            }
            .background(theme.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .tint(theme.accent)
        .preferredColorScheme(.dark)
    }

    /// Block or allow. The segmented control stays small, so large text gets two full-width choices.
    @ViewBuilder
    private var choice: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: Rhythm.tight) {
                ChoiceRow(title: "Block", selected: blocked, theme: theme) { blocked = true }
                ChoiceRow(title: "Allow", selected: !blocked, theme: theme) { blocked = false }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Action")
        } else {
            Picker("Action", selection: $blocked) {
                Text("Block").tag(true)
                Text("Allow").tag(false)
            }
            .pickerStyle(.segmented)
        }
    }

    private func submit() {
        guard !name.isEmpty else { return }
        let action: HouseholdAction = blocked ? .blockDomain(named: name) : .allowDomain(named: name)
        dismiss()
        onAction(action)
    }
}

/// One labelled choice with a selection mark that is a symbol, not only a color.
private struct ChoiceRow: View {
    var title: String
    var selected: Bool
    var theme: StreetTheme
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Rhythm.line) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? theme.accent : theme.secondary)
                    .accessibilityHidden(true)
                Text(title)
                    .foregroundStyle(theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.title3.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .padding(Rhythm.line)
            .controlPlate(theme: theme)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}
