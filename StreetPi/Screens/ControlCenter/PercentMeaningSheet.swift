import SwiftUI

/// The short explainer for the ad-blocker percent. It is not the card's tap.
struct PercentMeaningSheet: View {
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
            .background(palette.ground)
            .navigationTitle("About this percent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDone)
                }
            }
        }
        .presentationDragIndicator(.visible)
    }
}
