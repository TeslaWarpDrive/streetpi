import StreetPiCore
import SwiftUI

struct DomainEditor: View {
    var theme: StreetTheme
    var onAction: (HouseholdAction) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""
    @State private var blocked = true

    private var name: String { draft.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            ControlScreen(wide: false) {
                ControlTitle(title: "One domain name", line: "This applies to everyone in the house. You will confirm before anything changes.", theme: theme)
                TextField("example.test", text: $draft, axis: .vertical)
                    .font(.body.monospaced())
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .padding(Rhythm.line)
                    .controlPlate(theme: theme)
                    .accessibilityLabel("Domain name")
                Picker("Action", selection: $blocked) {
                    Text("Block").tag(true)
                    Text("Allow").tag(false)
                }
                .pickerStyle(.segmented)
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

    private func submit() {
        guard !name.isEmpty else { return }
        let action: HouseholdAction = blocked ? .blockDomain(named: name) : .allowDomain(named: name)
        dismiss()
        onAction(action)
    }
}
