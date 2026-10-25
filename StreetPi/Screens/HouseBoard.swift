import Foundation
import StreetPiCore

/// Builds the House board from the current screen and the ad-blocker desk.
enum HouseBoard {
    static func make(screen: HouseScreen, desk: DNSDesk, now: Date) -> ControlBoard {
        let snapshot = screen.snapshot
        var board = ControlBoardBuilder.make(
            snapshot: snapshot,
            share: LookupShare.matching(summary: snapshot?.dns, desk: desk),
            deviceCount: snapshot?.dns == nil ? nil : desk.knownClients,
            headline: screen.status(now: now).headline,
            now: now
        )
        if snapshot?.dns == nil, let spoken = desk.spokenLine, spoken.isEmpty == false {
            board.headline = spoken
            board.blocker = BlockerTile(
                stateWord: "Quiet",
                percentText: "—",
                fraction: 0,
                fractionLine: spoken,
                explainer: spoken,
                canPause: false
            )
        }
        return board
    }
}
