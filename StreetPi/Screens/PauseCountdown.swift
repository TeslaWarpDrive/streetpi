import StreetPiCore
import SwiftUI

/// Uses the Pi's returned timer. A paused filter without a timer never invents an end time.
struct PauseCountdown: View {
    var endsAt: Date
    var now: Date

    @Environment(\.streetPiStill) private var still
    @Environment(\.afterglowPalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: AfterglowShape.tight) {
            if endsAt > now {
                if still {
                    Text(PauseLength.english(seconds: max(1, Int(endsAt.timeIntervalSince(now)))))
                        .font(.title2.monospacedDigit().bold())
                } else {
                    Text(timerInterval: now...endsAt, countsDown: true)
                        .font(.title2.monospacedDigit().bold())
                        .accessibilityLabel("Time until ad blocking turns back on")
                }
                Text("Turns back on at \(endsAt.formatted(date: .omitted, time: .shortened))")
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("The pause has ended. Refresh to check blocking.")
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .foregroundStyle(palette.attention)
        .accessibilityElement(children: .combine)
    }
}
