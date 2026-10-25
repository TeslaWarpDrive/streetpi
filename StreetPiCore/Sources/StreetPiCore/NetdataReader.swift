import Foundation

public struct NetdataHistoryLoad: Sendable, Equatable {
    public var series: [MetricSeries]
    public var containers: [NamedRow]
    public var alerts: [HouseAlert]
    public var chartNote: String?
    public var containerNote: String?
    public var alertNote: String?

    public init(
        series: [MetricSeries],
        containers: [NamedRow],
        alerts: [HouseAlert],
        chartNote: String?,
        containerNote: String?,
        alertNote: String?
    ) {
        self.series = series
        self.containers = containers
        self.alerts = alerts
        self.chartNote = chartNote
        self.containerNote = containerNote
        self.alertNote = alertNote
    }
}

/// Reads history, containers, and raised alarms from the local agent only.
public struct NetdataReader: Sendable {
    public var fetch: @Sendable (String) async throws -> AgentHTTPResult
    public var now: @Sendable () -> Date

    public init(
        fetch: @escaping @Sendable (String) async throws -> AgentHTTPResult,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.fetch = fetch
        self.now = now
    }

    public func load() async -> NetdataHistoryLoad {
        let charts = await pull(NetdataHistoryAPI.chartsPath)
        let offline = chartsFailedOffline(charts)
        let containers = containerSection(charts, offline: offline)
        let series = await seriesSection(charts, offline: offline)
        let alerts = await alarmSection(offline: offline)
        return NetdataHistoryLoad(
            series: series.series,
            containers: containers.rows,
            alerts: alerts.rows,
            chartNote: series.note,
            containerNote: containers.note,
            alertNote: alerts.note
        )
    }

    private func pull(_ path: String) async -> Result<AgentHTTPResult, NetdataProblem> {
        do {
            return .success(try await fetch(path))
        } catch let problem as NetdataProblem {
            return .failure(problem)
        } catch {
            return .failure(.offline)
        }
    }

    private func chartsFailedOffline(_ charts: Result<AgentHTTPResult, NetdataProblem>) -> Bool {
        if case .failure(.offline) = charts { return true }
        return false
    }

    private func containerSection(
        _ charts: Result<AgentHTTPResult, NetdataProblem>,
        offline: Bool
    ) -> (rows: [NamedRow], note: String?) {
        if offline { return ([], LiveReadCopy.offline) }
        guard case .success(let result) = charts else { return ([], LiveReadCopy.containers) }
        do {
            return (try NetdataDecode.containers(from: result), nil)
        } catch {
            return ([], LiveReadCopy.containers)
        }
    }

    private func seriesSection(
        _ charts: Result<AgentHTTPResult, NetdataProblem>,
        offline: Bool
    ) async -> (series: [MetricSeries], note: String?) {
        if offline { return ([], LiveReadCopy.offline) }
        var ids: [HistoryKind: String] = [:]
        if case .success(let result) = charts {
            ids = (try? NetdataDecode.chartIDs(from: result)) ?? [:]
        }
        var series: [MetricSeries] = []
        for kind in HistoryKind.allCases {
            let chart = ids[kind] ?? kind.fallbackChart
            if let item = await oneSeries(chart: chart, kind: kind) {
                series.append(item)
            }
        }
        if series.isEmpty { return ([], LiveReadCopy.charts) }
        return (series, nil)
    }

    private func oneSeries(chart: String, kind: HistoryKind) async -> MetricSeries? {
        guard let path = NetdataHistoryAPI.dataPath(chart: chart) else { return nil }
        if let series = await decodeSeries(path: path, kind: kind) {
            return series
        }
        guard let fallback = NetdataHistoryAPI.dataPathV3(context: kind.context) else { return nil }
        return await decodeSeries(path: fallback, kind: kind)
    }

    private func decodeSeries(path: String, kind: HistoryKind) async -> MetricSeries? {
        guard case .success(let result) = await pull(path) else { return nil }
        return try? NetdataDecode.series(from: result, kind: kind, ending: now())
    }

    private func alarmSection(offline: Bool) async -> (rows: [HouseAlert], note: String?) {
        if offline { return ([], LiveReadCopy.offline) }
        guard case .success(let result) = await pull(NetdataHistoryAPI.alarmsPath) else {
            return ([], LiveReadCopy.alarms)
        }
        do {
            return (try NetdataDecode.alarms(from: result), nil)
        } catch {
            return ([], LiveReadCopy.alarms)
        }
    }
}
