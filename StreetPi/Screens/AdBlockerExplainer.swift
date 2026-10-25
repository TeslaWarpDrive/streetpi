import StreetPiCore
import SwiftUI

/// Short plain-English note for the ad-blocker percent.
struct AdBlockerExplainer: View {
    var reading: HomeAdBlockerReading

    @Environment(\.dismiss) private var dismiss
    @Environment(\.afterglowPalette) private var palette

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AfterglowShape.line) {
                    Text("The percent")
                        .font(.title.bold())
                        .foregroundStyle(palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text(reading.explainer)
                        .font(.body)
                        .foregroundStyle(palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(reading.fractionLine)
                        .font(.body)
                        .foregroundStyle(palette.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(AfterglowShape.page)
                .frame(maxWidth: 560, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
            .background(palette.ground)
            .navigationTitle("The percent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done", action: close)
                }
            }
        }
        .afterglowScoped()
        .preferredColorScheme(.dark)
    }

    private func close() {
        dismiss()
    }
}

private extension View {
    func afterglowScoped() -> some View {
        AfterglowScope { self }
    }
}
