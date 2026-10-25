import StreetPiCore
import SwiftUI

/// Streaming, Remote, DNS, and Address. Four across when they fit, otherwise two rows.
struct SquareRow: View {
    var squares: [ServiceSquare]
    var onOpen: (HouseGroup) -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: AfterglowShape.line) {
                row(squares)
            }
            VStack(alignment: .leading, spacing: AfterglowShape.line) {
                HStack(alignment: .top, spacing: AfterglowShape.line) {
                    row(Array(squares.prefix(2)))
                }
                HStack(alignment: .top, spacing: AfterglowShape.line) {
                    row(Array(squares.dropFirst(2)))
                }
            }
        }
    }

    private func row(_ squares: [ServiceSquare]) -> some View {
        ForEach(squares) { square in
            ServiceSquareTile(square: square) {
                onOpen(square.group)
            }
        }
    }
}
