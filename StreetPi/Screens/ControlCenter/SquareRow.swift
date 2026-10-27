import StreetPiCore
import SwiftUI

/// Streaming, Remote, DNS, and Address.
/// Default text keeps four equal squares. Larger accessibility sizes drop to two rows, then one column.
struct SquareRow: View {
    var squares: [ServiceSquare]
    var onOpen: (HouseGroup) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            ViewThatFits(in: .horizontal) {
                paired
                VStack(alignment: .leading, spacing: gap) {
                    tiles(squares, square: false)
                }
            }
        } else {
            HStack(alignment: .top, spacing: gap) {
                tiles(squares, square: true)
            }
        }
    }

    private let gap = BoardColumns<EmptyView, EmptyView>.phoneGap

    private var paired: some View {
        VStack(alignment: .leading, spacing: gap) {
            HStack(alignment: .top, spacing: gap) {
                tiles(Array(squares.prefix(2)), square: false)
            }
            HStack(alignment: .top, spacing: gap) {
                tiles(Array(squares.dropFirst(2)), square: false)
            }
        }
    }

    private func tiles(_ squares: [ServiceSquare], square: Bool) -> some View {
        ForEach(squares) { squareTile in
            ServiceSquareTile(square: squareTile, readsAsSquare: square) {
                onOpen(squareTile.group)
            }
            .frame(maxWidth: .infinity, alignment: .top)
        }
    }
}
