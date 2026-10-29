import Foundation

public struct NetdataPoint: Sendable, Equatable {
    public var names: [String]
    public var values: [Double]

    public init(names: [String], values: [Double]) {
        self.names = names
        self.values = values
    }
}

public struct NetdataChartPlan: Sendable, Equatable {
    public var cpu: String
    public var memory: String
    public var disk: String
    public var temperature: String?
    public var uptime: String

    public init(cpu: String, memory: String, disk: String, temperature: String?, uptime: String) {
        self.cpu = cpu
        self.memory = memory
        self.disk = disk
        self.temperature = temperature
        self.uptime = uptime
    }

    public static let fallback = NetdataChartPlan(
        cpu: "system.cpu",
        memory: "system.ram",
        disk: "disk_space./",
        temperature: nil,
        uptime: "system.uptime"
    )
}

public struct NetdataMeters: Sendable, Equatable {
    public var hostName: String
    public var reading: MachineReading

    public init(hostName: String, reading: MachineReading) {
        self.hostName = hostName
        self.reading = reading
    }
}

public enum NetdataDecode {
    public static let temperatureCandidates = [
        "sensors.temperature_cpu_thermal",
        "sensors.cpu_thermal-virtual-0_temperature",
        "sensors.temperature_thermal_zone0_temperature",
        "cpu.temperature",
        "system.hw.sensor.temperature.input",
    ]

    public static let diskCandidates = [
        "disk_space./",
        "disk_space._",
        "disk_space._root",
    ]

    public static func isRedirect(_ reply: NetdataReply) -> Bool {
        (300..<400).contains(reply.status)
    }

    public static func isJSONObject(_ data: Data) -> Bool {
        (try? object(data)) != nil
    }

    public static func hostName(from data: Data) throws -> String {
        let root = try object(data)
        if let name = text(root["hostname"]) {
            return name
        }
        if let hosts = root["mirrored_hosts"] as? [Any] {
            for host in hosts {
                if let name = text(host) {
                    return name
                }
            }
        }
        if let labels = root["labels"] as? [String: Any] {
            if let name = text(labels["_hostname"]) ?? text(labels["hostname"]) {
                return name
            }
        }
        throw NetdataProblem.notUnderstood
    }

    public static func point(from data: Data) throws -> NetdataPoint {
        let root = try object(data)
        if root["error"] != nil {
            throw NetdataProblem.notUnderstood
        }
        if let names = strings(root["dimension_names"]) {
            if let values = numbers(root["view_latest_values"]), values.count == names.count, !values.isEmpty {
                return NetdataPoint(names: names, values: values)
            }
            if let values = numbers(root["latest_values"]), values.count == names.count, !values.isEmpty {
                return NetdataPoint(names: names, values: values)
            }
        }
        let payload = root["result"] as? [String: Any] ?? root
        guard let labels = strings(payload["labels"]),
              let rows = payload["data"] as? [Any],
              let row = rows.last
        else { throw NetdataProblem.notUnderstood }
        return try point(labels: labels, row: row)
    }

    public static func chartPlan(from data: Data?) -> NetdataChartPlan {
        guard let data, let root = try? object(data) else { return .fallback }
        let charts = root["charts"] as? [String: Any] ?? [:]
        var cpu: String?
        var memory: String?
        var uptime: String?
        var disk: String?
        var bestDisk = 0
        var temperature: String?
        var bestTemperature = 0
        for (key, value) in charts {
            guard let chart = value as? [String: Any] else { continue }
            let id = text(chart["id"]) ?? key
            let context = text(chart["context"]) ?? ""
            let family = text(chart["family"]) ?? ""
            let units = text(chart["units"]) ?? ""
            let title = text(chart["title"]) ?? ""
            if context == "system.cpu" || id == "system.cpu" { cpu = id }
            if context == "system.ram" || id == "system.ram" { memory = id }
            if context == "system.uptime" || id == "system.uptime" { uptime = id }
            if let rank = diskRank(id: id, context: context, family: family), rank > bestDisk {
                bestDisk = rank
                disk = id
            }
            if let rank = temperatureRank(id: id, context: context, family: family, units: units, title: title),
               rank > bestTemperature {
                bestTemperature = rank
                temperature = id
            }
        }
        return NetdataChartPlan(
            cpu: cpu ?? NetdataChartPlan.fallback.cpu,
            memory: memory ?? NetdataChartPlan.fallback.memory,
            disk: disk ?? NetdataChartPlan.fallback.disk,
            temperature: temperature,
            uptime: uptime ?? NetdataChartPlan.fallback.uptime
        )
    }

    public static func reading(
        cpu: NetdataPoint?,
        memory: NetdataPoint?,
        disk: NetdataPoint?,
        temperature: NetdataPoint?,
        uptime: NetdataPoint?
    ) -> MachineReading {
        MachineReading(
            cpuUsedFraction: cpu.flatMap(cpuFraction),
            temperatureCelsius: temperature.flatMap(celsius),
            memoryUsedFraction: memory.flatMap(shareUsed),
            diskUsedFraction: disk.flatMap(shareUsed),
            uptimeSeconds: uptime.flatMap(uptimeSeconds)
        )
    }

    /// `system.cpu` dimensions are percentages of the whole processor. Netdata hides `idle`
    /// by default, so without it the visible dimensions already add up to the busy share.
    public static func cpuFraction(_ point: NetdataPoint) -> Double? {
        guard !point.values.isEmpty else { return nil }
        var busy: Double?
        var idle: Double?
        for (name, value) in zip(point.names, point.values) {
            if isIdle(name) {
                idle = (idle ?? 0) + value
            } else {
                busy = (busy ?? 0) + value
            }
        }
        guard let idle else { return clamp((busy ?? 0) / 100) }
        guard let busy else { return clamp((100 - idle) / 100) }
        let total = busy + idle
        guard total > 0 else { return nil }
        return clamp(busy / total)
    }

    static func isIdle(_ name: String) -> Bool {
        let lowered = name.lowercased()
        return lowered == "idle" || lowered.hasSuffix(".idle")
    }

    public static func shareUsed(_ point: NetdataPoint) -> Double? {
        guard let used = value(named: "used", in: point) else { return nil }
        let total = point.values.reduce(0, +)
        guard total > 0 else { return nil }
        return clamp(used / total)
    }

    public static func celsius(_ point: NetdataPoint) -> Double? {
        let preferred = value(named: "input", in: point)
            ?? value(named: "temperature", in: point)
            ?? (point.values.count == 1 ? point.values[0] : nil)
        guard let preferred, preferred > -20, preferred < 140 else { return nil }
        return preferred
    }

    public static func uptimeSeconds(_ point: NetdataPoint) -> Double? {
        let seconds = value(named: "uptime", in: point) ?? (point.values.count == 1 ? point.values[0] : nil)
        guard let seconds, seconds >= 0 else { return nil }
        return seconds
    }

    private static func point(labels: [String], row: Any) throws -> NetdataPoint {
        guard let cells = row as? [Any], cells.count == labels.count, !labels.isEmpty else {
            throw NetdataProblem.notUnderstood
        }
        let start = labels[0] == "time" ? 1 : 0
        var names: [String] = []
        var values: [Double] = []
        for index in start..<labels.count {
            guard let number = double(cells[index]) else { throw NetdataProblem.notUnderstood }
            names.append(labels[index])
            values.append(number)
        }
        guard !names.isEmpty else { throw NetdataProblem.notUnderstood }
        return NetdataPoint(names: names, values: values)
    }

    private static func diskRank(id: String, context: String, family: String) -> Int? {
        let isDisk = context == "disk.space" || id.hasPrefix("disk_space.")
        guard isDisk else { return nil }
        if family == "/" || id == "disk_space./" { return 3 }
        if family == "/root" || id.contains("root") { return 2 }
        return 1
    }

    private static func temperatureRank(
        id: String,
        context: String,
        family: String,
        units: String,
        title: String
    ) -> Int? {
        let blob = "\(id) \(context) \(family) \(title)".lowercased()
        guard blob.contains("temperature"), !blob.contains("alarm") else { return nil }
        var rank = 1
        if blob.contains("cpu") || blob.contains("thermal") || blob.contains("rpi") || blob.contains("soc") {
            rank += 3
        }
        if units.lowercased().contains("celsius") {
            rank += 1
        }
        return rank
    }

    private static func value(named name: String, in point: NetdataPoint) -> Double? {
        for (index, label) in point.names.enumerated() where label == name {
            return point.values[index]
        }
        return nil
    }

    private static func clamp(_ value: Double) -> Double {
        min(1, max(0, value))
    }

    private static func object(_ data: Data) throws -> [String: Any] {
        let value: Any
        do {
            value = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw NetdataProblem.notUnderstood
        }
        guard let root = value as? [String: Any] else { throw NetdataProblem.notUnderstood }
        return root
    }

    private static func text(_ value: Any?) -> String? {
        guard let value = value as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func strings(_ value: Any?) -> [String]? {
        guard let value = value as? [Any] else { return nil }
        let names = value.compactMap { $0 as? String }
        return names.count == value.count ? names : nil
    }

    private static func numbers(_ value: Any?) -> [Double]? {
        guard let value = value as? [Any] else { return nil }
        let numbers = value.compactMap(double)
        return numbers.count == value.count ? numbers : nil
    }

    private static func double(_ value: Any?) -> Double? {
        if let value = value as? Double { return value }
        if let value = value as? Int { return Double(value) }
        if let value = value as? NSNumber { return value.doubleValue }
        return nil
    }
}
