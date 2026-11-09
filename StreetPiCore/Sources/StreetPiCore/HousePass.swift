import Foundation

/// One charts-and-log pass. Each half uses its own result.
/// While the Pi is out of reach, a half that succeeded stays off the house, even when the other half missed.
/// A miss writes only that half's note. Every other road keeps the assignments it had before.
public struct HousePass: Sendable, Equatable {
    public var series: [MetricSeries]
    public var chartNote: String?
    public var containers: [NamedRow]
    public var containerNote: String?
    public var alerts: [HouseAlert]
    public var alertNote: String?
    public var queries: LiveLogFeed
    public var liveNote: String?
    public var text: TextLogFeed
    public var textNote: String?

    public init(
        series: [MetricSeries],
        chartNote: String?,
        containers: [NamedRow],
        containerNote: String?,
        alerts: [HouseAlert],
        alertNote: String?,
        queries: LiveLogFeed,
        liveNote: String?,
        text: TextLogFeed,
        textNote: String?
    ) {
        self.series = series
        self.chartNote = chartNote
        self.containers = containers
        self.containerNote = containerNote
        self.alerts = alerts
        self.alertNote = alertNote
        self.queries = queries
        self.liveNote = liveNote
        self.text = text
        self.textNote = textNote
    }

    /// A pull reads charts without the logs, so the log half is empty and only `appliedHistory` is used.
    public init(
        history: NetdataHistoryLoad,
        queries: LiveLogFeed = LiveLogFeed(),
        liveNote: String? = nil,
        text: TextLogFeed = TextLogFeed(),
        textNote: String? = nil
    ) {
        self.init(
            series: history.series, chartNote: history.chartNote,
            containers: history.containers, containerNote: history.containerNote,
            alerts: history.alerts, alertNote: history.alertNote,
            queries: queries, liveNote: liveNote, text: text, textNote: textNote
        )
    }

    public func applied(
        to machine: MachineDesk,
        desk: DNSDesk,
        mode: ConnectionMode
    ) -> (machine: MachineDesk, desk: DNSDesk) {
        let desk = desk.applyingLiveLog(
            queries: queries, liveNote: liveNote, text: text, textNote: textNote, mode: mode
        )
        return (appliedHistory(to: machine, mode: mode), desk)
    }

    /// Charts, containers, and alarms only. The loop and a pull both paint through here.
    public func appliedHistory(to machine: MachineDesk, mode: ConnectionMode) -> MachineDesk {
        var machine = machine
        write(&machine.series, note: &machine.chartNote, incoming: series, incomingNote: chartNote, mode: mode)
        write(
            &machine.containers, note: &machine.containerNote,
            incoming: containers, incomingNote: containerNote, mode: mode
        )
        write(&machine.alerts, note: &machine.alertNote, incoming: alerts, incomingNote: alertNote, mode: mode)
        return machine
    }

    /// `incomingNote == nil` is this half's own success. A miss on another half cannot open it.
    private func write<Value>(
        _ current: inout Value,
        note currentNote: inout String?,
        incoming: Value,
        incomingNote: String?,
        mode: ConnectionMode
    ) {
        let succeeded = incomingNote == nil
        guard mode.paintsHouse(readSucceeded: succeeded) || incomingNote != nil else { return }
        if succeeded {
            current = incoming
        }
        currentNote = incomingNote
    }
}
