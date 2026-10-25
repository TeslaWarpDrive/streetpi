import StreetPiCore
import SwiftUI

/// Streaming, Remote, DNS, and Address. Four across when they fit, then two rows, then one column.
struct SquareRow: View {
    var squares: [ServiceSquare]
    var onOpen: (HouseGroup) -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: AfterglowShape.line) {
                row(squares, compresses: false)
            }
            VStack(alignment: .leading, spacing: AfterglowShape.line) {
                HStack(alignment: .top, spacing: AfterglowShape.line) {
                    row(Array(squares.prefix(2)), compresses: false)
                }
                HStack(alignment: .top, spacing: AfterglowShape.line) {
                    row(Array(squares.dropFirst(2)), compresses: false)
                }
            }
            VStack(alignment: .leading, spacing: AfterglowShape.line) {
                row(squares, compresses: true)
            }
        }
    }

    private func row(_ squares: [ServiceSquare], compresses: Bool) -> some View {
        ForEach(squares) { square in
            ServiceSquareTile(square: square, compresses: compresses) {
                onOpen(square.group)
            }
        }
    }
}
