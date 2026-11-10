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

    /// Charts, and the containers and alarms that arrive in the same read.
    /// A miss keeps the last good rows and says why, the same as the loop.
    /// Offline lands only the halves that missed.
    func applyHistory(_ history: NetdataHistoryLoad) {
        let paint = mode.paintsHouse(readSucceeded: true)
        if paint || history.chartNote != nil {
            if history.chartNote == nil {
                machine.series = history.series
            }
            machine.chartNote = history.chartNote
        }
        if paint || history.containerNote != nil {
            if history.containerNote == nil {
                machine.containers = history.containers
            }
            machine.containerNote = history.containerNote
        }
        if paint || history.alertNote != nil {
            if history.alertNote == nil {
                machine.alerts = history.alerts
            }
            machine.alertNote = history.alertNote
        }
    }
}
