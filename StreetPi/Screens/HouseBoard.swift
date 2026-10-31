import Foundation
import StreetPiCore

/// Builds the House board from the current screen and the ad-blocker desk.
enum HouseBoard {
    static func make(screen: HouseScreen, desk: DNSDesk, now: Date, piNotice: String? = nil) -> ControlBoard {
        let snapshot = screen.snapshot
        var board = ControlBoardBuilder.make(
            snapshot: snapshot,
            share: LookupShare.matching(summary: snapshot?.dns, desk: desk),
            deviceCount: snapshot?.dns == nil ? nil : desk.knownClients,
            headline: screen.status(now: now).headline,
            now: now,
            tone: screen.status(now: now).tone
        )
        if snapshot?.machine == nil, let piNotice, piNotice.isEmpty == false {
            board.pi.line = piNotice
        }
        if snapshot?.dns == nil, let spoken = desk.spokenLine, spoken.isEmpty == false {
            board.headline = spoken
            board.tone = .attention
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

    /// Status-page tiles replace the sample monitors, backups, and squares.
    /// The percent stays on the Pi-hole share. The Pi meters stay on the machine reading.
    static func applying(status: HouseStatusBoard, to board: ControlBoard) -> ControlBoard {
        var next = board
        next.headline = status.briefing.headline
        next.tone = status.briefing.tone
        let wanted: [HouseGroup] = [.streaming, .remoteHelp, .internet, .address]
        let chosen = wanted.compactMap { group in
            status.tiles.first { $0.id == group }
        }
        let tiles = chosen.isEmpty ? Array(status.tiles.prefix(4)) : chosen
        next.squares = tiles.map { tile in
            ServiceSquare(
                id: tile.title,
                title: tile.title,
                word: tile.summary,
                tone: tile.tone,
                group: tile.id
            )
        }
        if let monitors = status.tiles.first(where: { $0.id == .monitors }) {
            next.monitors = MonitorTile(
                figure: monitors.summary,
                line: monitors.summary,
                marks: monitors.rows.map { row in
                    MonitorMark(id: row.id, name: row.name, up: row.tone == .calm, word: row.state)
                }
            )
        }
        if let backups = status.tiles.first(where: { $0.id == .backups }) {
            next.backups = BackupTile(
                figure: backups.summary,
                line: backups.summary,
                tone: backups.tone
            )
        }
        return next
    }
}
