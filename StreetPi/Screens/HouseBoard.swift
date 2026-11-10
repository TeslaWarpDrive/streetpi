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
    /// A calm briefing does not paint over a certificate prompt or a failed read.
    static func applying(status: HouseStatusBoard, to board: ControlBoard) -> ControlBoard {
        var next = board
        let briefing = status.briefing
        if keepsReadFailure(board.headline, against: briefing) == false {
            next.headline = briefing.headline
            next.tone = briefing.tone
        }
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

    /// "The house is up." must not replace the sentence Ad blocker is already showing.
    /// A status page that has its own trouble may still name that trouble.
    private static func keepsReadFailure(_ headline: String, against briefing: PlainEnglishStatus) -> Bool {
        briefing.tone == .calm && readFailureHeadlines.contains(headline)
    }

    /// Pill sentences from a failed ad-blocker read, or from an unreachable house.
    /// The ad-blocker offline line is its own sentence. Away uncertainty is not here,
    /// so a calm status page can still speak over "not sure" and "no checks".
    private static let readFailureHeadlines: Set<String> = [
        AdBlockerVoice.unreachableTitle,
        PiholeProblem.needsPassword.title,
        PiholeProblem.refused.title,
        PiholeProblem.offline.title,
        PiholeProblem.needsSignIn.title,
        PiholeProblem.notUnderstood.title,
        PiholeProblem.invalidDomain.title,
        PiholeProblem.invalidPause.title,
        PiholeProblem.notSetUp.title,
        PiholeProblem.dnsOff.title,
        PiholeProblem.certificateChanged.title,
        PiholeProblem.pinKept.title,
        PiholeProblem.busy.title,
        PiholeProblem.gravityFailed.title,
        PiholeProblem.untrusted.title,
        PiholeProblem.rateLimited.title,
    ]
}
