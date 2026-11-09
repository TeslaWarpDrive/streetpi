import StreetPiCore

extension RootView {
    /// One pass of the tiles that otherwise wait on their own loops.
    /// Those loops keep their own wait, and a miss here does not look for a new road.
    func refreshHouseTiles(_ reads: Set<ManualRefresh.Source>) async {
        async let temperature: Void = refreshTile(.temperature, in: reads)
        async let charts: Void = refreshTile(.charts, in: reads)
        async let monitors: Void = refreshTile(.monitors, in: reads)
        _ = await (temperature, charts, monitors)
    }

    func loadHistory() async -> NetdataHistoryLoad {
        let road = liveRoad
        let reader = NetdataHistoryReader(
            transport: NetdataLiveTransport(client: road.sender, base: road.endpoints.netdata, isAway: road.isAway),
            now: { Date() }
        )
        return await reader.load()
    }

    func presentMeters(_ result: Result<NetdataMeters, NetdataProblem>) {
        switch result {
        case .success(let meters):
            apply(meters)
        case .failure(let problem):
            liveReading = nil
            piNotice = problem.sentence
        }
    }

    /// Charts, and the containers and alarms that arrive in the same read.
    /// A miss keeps the last good rows and says why, the same as the loop.
    func applyHistory(_ history: NetdataHistoryLoad) {
        if history.chartNote == nil {
            machine.series = history.series
        }
        machine.chartNote = history.chartNote
        if history.containerNote == nil {
            machine.containers = history.containers
        }
        machine.containerNote = history.containerNote
        if history.alertNote == nil {
            machine.alerts = history.alerts
        }
        machine.alertNote = history.alertNote
    }

    private func refreshTile(_ source: ManualRefresh.Source, in reads: Set<ManualRefresh.Source>) async {
        guard reads.contains(source) else { return }
        switch source {
        case .temperature:
            await refreshTemperature()
        case .charts:
            await refreshCharts()
        case .monitors:
            await refreshMonitors()
        case .adBlocker, .mailbox:
            break
        }
    }

    private func refreshTemperature() async {
        let road = liveRoad
        let refresh = PiMeterRefresh(client: road.sender, base: road.endpoints.netdata, isAway: road.isAway)
        guard let result = await refresh.load() else { return }
        guard Task.isCancelled == false else { return }
        presentMeters(result)
        showMachine()
    }

    private func refreshCharts() async {
        let history = await loadHistory()
        guard Task.isCancelled == false else { return }
        applyHistory(history)
    }

    private func refreshMonitors() async {
        do {
            let load = try await readStatusPage()
            guard Task.isCancelled == false else { return }
            statusBoard = load.board
        } catch is CancellationError {
            return
        } catch {
            return
        }
    }
}
