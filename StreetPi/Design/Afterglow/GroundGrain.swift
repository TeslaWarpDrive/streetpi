import SwiftUI

/// Static film grain for the dark ground. Light mode leaves this off.
struct GroundGrain: View {
    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 4
            var row: CGFloat = 0
            while row < size.height {
                var column: CGFloat = 0
                while column < size.width {
                    let seed = (Int(column) &* 13 &+ Int(row) &* 7) % 5
                    if seed == 0 {
                        let dot = CGRect(x: column, y: row, width: 1, height: 1)
                        context.fill(Path(dot), with: .color(.white.opacity(0.55)))
                    }
                    column += step
                }
                row += step
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
