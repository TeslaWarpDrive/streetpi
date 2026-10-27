import Foundation

public struct MachineDesk: Sendable, Equatable, Codable {
    public var modelName: String
    public var host: String
    public var series: [MetricSeries]
    public var services: [NamedRow]
    public var containers: [NamedRow]
    public var alerts: [HouseAlert]
    public var chartNote: String?
    public var containerNote: String?
    public var alertNote: String?

    public init(
        modelName: String,
        host: String,
        series: [MetricSeries],
        services: [NamedRow],
        containers: [NamedRow],
        alerts: [HouseAlert],
        chartNote: String? = nil,
        containerNote: String? = nil,
        alertNote: String? = nil
    ) {
        self.modelName = modelName
        self.host = host
        self.series = series
        self.services = services
        self.containers = containers
        self.alerts = alerts
        self.chartNote = chartNote
        self.containerNote = containerNote
        self.alertNote = alertNote
    }
}

extension MachineDesk {
    /// Production stand-in until a Pi reader exists. No sample meters.
    public static let unread = MachineDesk(
        modelName: "No reading yet",
        host: "the Pi",
        series: [],
        services: [],
        containers: [],
        alerts: []
    )

    public static let houseFixture = MachineDesk(
        modelName: "Pi 5",
        host: "fixture.local",
        series: [
            series("cpu", "Processor", "Share of the processor, from the sample."),
            series("temperature", "Temperature", "Degrees, from the sample."),
            series("memory", "Memory", "Share of memory, from the sample."),
            series("disk", "Disk", "Share of the disk, from the sample."),
        ],
        services: [
            NamedRow(id: "filter", name: "Ad blocker", detail: "Up"),
            NamedRow(id: "names", name: "Name lookup", detail: "Up"),
            NamedRow(id: "house", name: "House controls", detail: "Up"),
        ],
        containers: [
            NamedRow(id: "media", name: "Media helper", detail: "Running"),
            NamedRow(id: "status", name: "Status page", detail: "Running"),
        ],
        alerts: []
    )

    /// Empty shell for a real read. Fixtures stay on `houseFixture`.
    public static let quiet = MachineDesk(
        modelName: "Pi",
        host: "This house",
        series: [],
        services: [],
        containers: [],
        alerts: []
    )

    /// Production desk before the charts agent answers. No sample series.
    public static let livePlaceholder = MachineDesk(
        modelName: "Raspberry Pi",
        host: "",
        series: [],
        services: [],
        containers: [],
        alerts: []
    )

    private static func series(_ id: String, _ title: String, _ caption: String) -> MetricSeries {
        MetricSeries(
            id: id,
            title: title,
            caption: caption,
            points: (0..<24).map { hour in
                MetricPoint(
                    hour: hour,
                    value: id == "temperature"
                        ? 48 + Double(hour % 6) * 2
                        : 0.2 + Double((hour + id.count) % 6) * 0.08
                )
            }
        )
    }
}

public struct NetdataRoute: Sendable, Equatable {
    public var method: String
    public var path: String

    public init(method: String, path: String) {
        self.method = method
        self.path = path
    }
}

public enum NetdataAPI {
    /// Chart families a look-only client can read. No host, no login.
    public static let chartFamilies = [
        "system.cpu",
        "system.ram",
        "disk.space",
        "sensors.temperature",
        "system.uptime",
        "systemd.service",
        "cgroup.docker",
    ]

    public static let routes: [NetdataRoute] = [
        NetdataRoute(method: "GET", path: "/api/v1/info"),
        NetdataRoute(method: "GET", path: "/api/v1/charts"),
        NetdataRoute(method: "GET", path: "/api/v1/data"),
        NetdataRoute(method: "GET", path: "/api/v3/data"),
        NetdataRoute(method: "GET", path: "/api/v1/alarms"),
    ]
}

public enum StatusPageAPI {
    /// Public status page. No login and no host in the path.
    public static let route = NetdataRoute(method: "GET", path: "/api/status-page/house")
}
