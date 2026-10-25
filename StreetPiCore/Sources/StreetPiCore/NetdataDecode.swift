import Foundation

public enum HistoryKind: String, CaseIterable, Sendable {
    case processor
    case memory
    case disk
    case temperature

    public var title: String {
        switch self {
        case .processor: "Processor"
        case .memory: "Memory"
        case .disk: "Disk"
        case .temperature: "Temperature"
        }
    }

    public var caption: String {
        switch self {
        case .processor: "Share of the processor over the last day."
        case .memory: "Share of memory over the last day."
        case .disk: "Share of the disk over the last day."
        case .temperature: "Degrees over the last day."
        }
    }

    public var context: String {
        switch self {
        case .processor: "system.cpu"
        case .memory: "system.ram"
        case .disk: "disk.space"
        case .temperature: "sensors.temperature"
        }
    }

    public var fallbackChart: String {
        switch self {
        case .processor: "system.cpu"
        case .memory: "system.ram"
        case .disk: "disk_space._"
        case .temperature: "sensors.temperature"
        }
    }
}

enum NetdataPayload {
    static func value(from result: AgentHTTPResult) throws -> Any {
        try reject(result)
        do {
            return try JSONSerialization.jsonObject(with: result.body)
        } catch {
            throw NetdataProblem.notUnderstood
        }
    }

    static func object(from result: AgentHTTPResult) throws -> [String: Any] {
        let value = try value(from: result)
        guard let object = value as? [String: Any] else { throw NetdataProblem.notUnderstood }
        return object
    }

    static func reject(_ result: AgentHTTPResult) throws {
        if result.redirected || (300...399).contains(result.status) {
            throw NetdataProblem.notUnderstood
        }
        if result.status == 0 { throw NetdataProblem.offline }
        guard (200...299).contains(result.status) else { throw NetdataProblem.notUnderstood }
        if result.body.isEmpty { throw NetdataProblem.notUnderstood }
    }
}

public enum NetdataDecode {
    public static func chartIDs(from result: AgentHTTPResult) throws -> [HistoryKind: String] {
        let root = try NetdataPayload.object(from: result)
        guard let charts = root["charts"] as? [String: Any] else { throw NetdataProblem.notUnderstood }
        var found: [HistoryKind: String] = [:]
        for (key, value) in charts {
            guard let chart = value as? [String: Any] else { continue }
            let context = (chart["context"] as? String) ?? ""
            let id = (chart["id"] as? String) ?? key
            guard let kind = historyKind(context: context, id: id) else { continue }
            found[kind] = preferred(kind, current: found[kind], candidate: id)
        }
        return found
    }

    public static func series(from result: AgentHTTPResult, kind: HistoryKind, ending: Date) throws -> MetricSeries {
        let value = try NetdataPayload.value(from: result)
        guard let table = HistoryTable.find(in: value) else { throw NetdataProblem.notUnderstood }
        let points = HourBuckets.points(table: table, kind: kind, ending: ending)
        return MetricSeries(id: kind.rawValue, title: kind.title, caption: kind.caption, points: points)
    }

    public static func containers(from result: AgentHTTPResult) throws -> [NamedRow] {
        let root = try NetdataPayload.object(from: result)
        guard let charts = root["charts"] as? [String: Any] else { throw NetdataProblem.notUnderstood }
        var rows: [String: NamedRow] = [:]
        for (key, value) in charts {
            guard let chart = value as? [String: Any] else { continue }
            guard let identity = containerIdentity(chart: chart, key: key) else { continue }
            if rows[identity.id] == nil || identity.prefersCPU {
                rows[identity.id] = NamedRow(id: identity.id, name: identity.name, detail: "Running")
            }
        }
        return rows.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    public static func alarms(from result: AgentHTTPResult) throws -> [HouseAlert] {
        let root = try NetdataPayload.object(from: result)
        guard let alarms = root["alarms"] as? [String: Any] else { throw NetdataProblem.notUnderstood }
        return alarms.compactMap { key, value in
            alert(key: key, value: value)
        }.sorted { $0.id < $1.id }
    }

    private static func historyKind(context: String, id: String) -> HistoryKind? {
        let contextName = context.lowercased()
        let chart = id.lowercased()
        if contextName == "system.cpu" || chart == "system.cpu" { return .processor }
        if contextName == "system.ram" || chart == "system.ram" { return .memory }
        if contextName == "disk.space" || chart.hasPrefix("disk_space") { return .disk }
        if contextName.contains("temperature") || chart.contains("temperature") { return .temperature }
        return nil
    }

    private static func preferred(_ kind: HistoryKind, current: String?, candidate: String) -> String {
        guard let current else { return candidate }
        switch kind {
        case .disk:
            let candidateRoot = candidate.contains("._")
            let currentRoot = current.contains("._")
            return candidateRoot && !currentRoot ? candidate : current
        case .temperature:
            let candidateCPU = candidate.lowercased().contains("cpu")
            let currentCPU = current.lowercased().contains("cpu")
            return candidateCPU && !currentCPU ? candidate : current
        case .processor, .memory:
            return current
        }
    }

    private struct ContainerIdentity {
        var id: String
        var name: String
        var prefersCPU: Bool
    }

    private static func containerIdentity(chart: [String: Any], key: String) -> ContainerIdentity? {
        let context = (chart["context"] as? String) ?? ""
        let type = (chart["type"] as? String) ?? ""
        let id = (chart["id"] as? String) ?? key
        let isGroup = context.hasPrefix("cgroup.") || type.hasPrefix("cgroup_") || id.hasPrefix("cgroup_")
        guard isGroup else { return nil }
        let cpu = context == "cgroup.cpu" || id.hasSuffix(".cpu")
        guard cpu || context == "cgroup.docker" else { return nil }
        let group = type.isEmpty ? id : type
        return ContainerIdentity(id: group, name: displayName(group), prefersCPU: cpu)
    }

    private static func displayName(_ group: String) -> String {
        var raw = group
        if raw.hasPrefix("cgroup_") {
            raw.removeFirst("cgroup_".count)
        }
        for prefix in ["docker_", "podman_", "lxc_"] where raw.hasPrefix(prefix) {
            raw.removeFirst(prefix.count)
            break
        }
        let words = raw.replacingOccurrences(of: "_", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return words.isEmpty ? group : words
    }

    private static func alert(key: String, value: Any) -> HouseAlert? {
        guard let alarm = value as? [String: Any] else { return nil }
        let status = ((alarm["status"] as? String) ?? "").uppercased()
        guard status == "WARNING" || status == "CRITICAL" else { return nil }
        let chart = (alarm["chart"] as? String) ?? key
        let tone: PlainEnglishStatus.Tone = status == "CRITICAL" ? .problem : .attention
        return HouseAlert(id: key, sentence: AlarmWords.sentence(chart: chart, status: status), tone: tone)
    }
}

enum AlarmWords {
    static func sentence(chart: String, status: String) -> String {
        let lead = status == "CRITICAL" ? "Critical." : "Warning."
        return "\(lead) \(subject(chart))"
    }

    static func subject(_ chart: String) -> String {
        let name = chart.lowercased()
        if name.contains("cpu") { return "The processor is busy." }
        if name.contains("ram") || name.contains("mem") { return "Memory is nearly full." }
        if name.contains("disk") || name.contains("space") { return "The disk is nearly full." }
        if name.contains("temp") { return "The Pi is hot." }
        return "An alarm is raised."
    }
}

struct HistoryTable {
    var labels: [String]
    var rows: [[Double]]

    static func find(in value: Any) -> HistoryTable? {
        if let rows = value as? [Any] {
            return bare(rows)
        }
        guard let object = value as? [String: Any] else { return nil }
        if let table = labeled(object) { return table }
        if let result = object["result"] {
            if let nested = result as? [String: Any], let table = labeled(nested) { return table }
            if let rows = result as? [Any] { return bare(rows) }
        }
        return nil
    }

    private static func labeled(_ object: [String: Any]) -> HistoryTable? {
        guard let labels = object["labels"] as? [String], let data = object["data"] as? [Any] else { return nil }
        guard !labels.isEmpty else { return nil }
        return HistoryTable(labels: labels, rows: data.compactMap(numberRow))
    }

    private static func bare(_ rows: [Any]) -> HistoryTable? {
        guard let first = rows.first as? [Any] else { return nil }
        let labels = first.compactMap { $0 as? String }
        guard labels.count == first.count, !labels.isEmpty else { return nil }
        return HistoryTable(labels: labels, rows: rows.dropFirst().compactMap(numberRow))
    }

    private static func numberRow(_ value: Any) -> [Double]? {
        guard let list = value as? [Any], !list.isEmpty else { return nil }
        if list.allSatisfy({ $0 is String }) { return nil }
        return list.map { number($0) ?? .nan }
    }

    private static func number(_ value: Any) -> Double? {
        if let value = value as? Double { return value }
        if let value = value as? Int { return Double(value) }
        if let value = value as? NSNumber { return value.doubleValue }
        return nil
    }
}

enum HourBuckets {
    static func points(table: HistoryTable, kind: HistoryKind, ending: Date) -> [MetricPoint] {
        let end = ending.timeIntervalSince1970
        let start = end - 24 * 3_600
        var sums = Array(repeating: 0.0, count: 24)
        var counts = Array(repeating: 0, count: 24)
        let timeIndex = table.labels.firstIndex { $0.caseInsensitiveCompare("time") == .orderedSame } ?? 0
        for row in table.rows {
            guard row.indices.contains(timeIndex) else { continue }
            let stamp = normalizeTime(row[timeIndex])
            guard stamp >= start, stamp < end else { continue }
            guard let reading = reduce(
                labels: table.labels,
                row: row,
                kind: kind,
                timeIndex: timeIndex
            ) else { continue }
            let index = min(23, max(0, Int((stamp - start) / 3_600)))
            sums[index] += reading
            counts[index] += 1
        }
        return (0..<24).map { hour in
            let value = counts[hour] > 0 ? sums[hour] / Double(counts[hour]) : 0
            return MetricPoint(hour: hour, value: value)
        }
    }

    private static func normalizeTime(_ stamp: Double) -> Double {
        stamp > 10_000_000_000 ? stamp / 1_000 : stamp
    }

    private static func reduce(labels: [String], row: [Double], kind: HistoryKind, timeIndex: Int) -> Double? {
        var pairs: [(String, Double)] = []
        for index in labels.indices where index != timeIndex && row.indices.contains(index) {
            let number = row[index]
            guard number.isFinite else { continue }
            pairs.append((labels[index].lowercased(), number))
        }
        guard !pairs.isEmpty else { return nil }
        switch kind {
        case .processor:
            return processor(pairs)
        case .memory, .disk:
            return share(pairs)
        case .temperature:
            return average(pairs.map(\.1))
        }
    }

    private static func processor(_ pairs: [(String, Double)]) -> Double {
        if let idle = pairs.first(where: { $0.0 == "idle" })?.1 {
            return remainder(idle)
        }
        return fraction(pairs.map(\.1).reduce(0, +))
    }

    private static func share(_ pairs: [(String, Double)]) -> Double {
        let total = pairs.map(\.1).reduce(0, +)
        if let used = pairs.first(where: { $0.0 == "used" })?.1, total > 0 {
            return min(1, max(0, used / total))
        }
        return fraction(total)
    }

    private static func remainder(_ idle: Double) -> Double {
        if idle <= 1.5 { return min(1, max(0, 1 - idle)) }
        return min(1, max(0, (100 - idle) / 100))
    }

    private static func fraction(_ sum: Double) -> Double {
        if sum <= 1.5 { return min(1, max(0, sum)) }
        return min(1, max(0, sum / 100))
    }

    private static func average(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }
}
