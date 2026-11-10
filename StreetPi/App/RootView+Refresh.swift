import Foundation
import StreetPiCore

extension RootView {
    /// One pass of the tiles that otherwise wait on their own loops.
    /// Those loops keep their own wait, and a miss here does not look for a new road.
    /// A result that finishes after the road or the saved settings change is dropped.
    /// Offline keeps a read that worked off the house here too, the same as the loops.
    func refreshHouseTiles(_ reads: Set<ManualRefresh.Source>) async {
        await ManualRefresh.refreshTiles(
            reads: reads,
            identity: { refreshIdentity() },
            temperature: ManualRefresh.Tile(
                load: { await loadMeters() },
                publish: { presentMeters($0) }
            ),
            charts: ManualRefresh.Tile(
                load: { await loadHistory() },
                publish: { applyHistory($0) }
            ),
            monitors: ManualRefresh.Tile(
                load: { try? await readStatusPage() },
                publish: { load in
                    if mode.paintsHouse(readSucceeded: true) {
                        statusBoard = load.board
                    }
                }
            )
        )
    }

    /// A pull can finish after sign-out. A sign-out during the read drops the board.
    /// A pull that started signed out still paints, because that ask puts the desk back.
    func refreshAdBlocker(_ asked: Bool) async {
        guard asked else { return }
        let startedSignedOut = signedOut
        let client = await clientForCurrentSettings()
        let board = await refresh(client, now: Date())
        guard ManualRefresh.mayPaintAdBlocker(
            mode: mode, startedSignedOut: startedSignedOut, signedOut: signedOut
        ) else {
            if signedOut { dnsSession.signedIn = false }
            return
        }
        apply(board)
    }

    private func loadMeters() async -> Result<NetdataMeters, NetdataProblem>? {
        let road = liveRoad
        let refresh = PiMeterRefresh(client: road.sender, base: road.endpoints.netdata, isAway: road.isAway)
        return await refresh.load()
    }

    func loadHistory() async -> NetdataHistoryLoad {
        let road = liveRoad
        let reader = NetdataHistoryReader(
            transport: NetdataLiveTransport(client: road.sender, base: road.endpoints.netdata, isAway: road.isAway),
            now: { Date() }
        )
        return await reader.load()
    }

    /// A miss always says why. Offline leaves a good read off the house and the machine card alone.
    func presentMeters(_ result: Result<NetdataMeters, NetdataProblem>) {
        switch result {
        case .success(let meters):
            guard mode.paintsHouse(readSucceeded: true) else { return }
            apply(meters)
        case .failure(let problem):
            liveReading = nil
            piNotice = problem.sentence
        }
        showMachine()
    }

    func apply(_ meters: NetdataMeters) {
        machine.host = meters.hostName
        machine.modelName = "Raspberry Pi"
        if meters.reading.hasSignal {
            liveReading = meters.reading
            piNotice = nil
        } else {
            liveReading = nil
            piNotice = NetdataProblem.notUnderstood.sentence
        }
    }

    /// Charts, and the containers and alarms that arrive in the same read.
    /// A miss keeps the last good rows and says why, the same as the loop.
    /// Offline lands only the halves that missed, by the same `HousePass` rule as the loop.
    func applyHistory(_ history: NetdataHistoryLoad) {
        machine = HousePass(history: history).appliedHistory(to: machine, mode: mode)
    }
}
