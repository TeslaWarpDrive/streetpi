import StreetPiCore
import SwiftUI

/// Full-screen Aurora wash. House uses the headline band; this stays for the launch handoff.
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
