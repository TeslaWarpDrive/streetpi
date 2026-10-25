import StreetPiCore
import SwiftUI

/// Streaming, Remote, DNS, and Address. Four across when they fit, then two rows, then one column.
struct SquareRow: View {
    var squares: [ServiceSquare]
    var onOpen: (HouseGroup) -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: gap) {
                row(squares, compresses: false)
            }
            VStack(alignment: .leading, spacing: gap) {
                HStack(alignment: .top, spacing: gap) {
                    row(Array(squares.prefix(2)), compresses: true)
                }
                HStack(alignment: .top, spacing: gap) {
                    row(Array(squares.dropFirst(2)), compresses: true)
                }
            }
            VStack(alignment: .leading, spacing: gap) {
                row(squares, compresses: true)
            }
        }
    }

    private let gap: CGFloat = 4

    private func row(_ squares: [ServiceSquare], compresses: Bool) -> some View {
        ForEach(squares) { square in
            ServiceSquareTile(square: square, compresses: compresses) {
                onOpen(square.group)
            }
        }
    }
}
