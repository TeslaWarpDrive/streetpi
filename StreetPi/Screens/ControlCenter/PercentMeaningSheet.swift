import SwiftUI

/// The tap-for-more explainer behind a big number. It is not the card's tap.
struct PercentMeaningSheet: View {
    var title: String
    var text: String
    var onDone: () -> Void

    @Environment(\.afterglowPalette) private var palette

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(text)
                    .font(.body)
                    .foregroundStyle(palette.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(AfterglowShape.page)
            }
            .background(palette.ground.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDone)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

/// One explainer: a short title and the plain-English text. Identifiable so a sheet can carry it.
struct NumberExplainer: Identifiable, Equatable {
    var title: String
    var text: String

    var id: String { title }
}
