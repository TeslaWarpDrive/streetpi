import StreetPiCore
import SwiftUI

/// Aurora wash behind the current Home screen. The porch layout stays as it is.
struct HomeAura: View {
    var tone: PlainEnglishStatus.Tone

    var body: some View {
        AfterglowScope {
            AuraView(tone: tone)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
