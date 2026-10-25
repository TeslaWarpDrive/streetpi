import Foundation

public enum PiholeDecode {
    public static func summary(from data: Data) throws -> DNSSummary {
        let root = try object(data)
        guard let queries = root["queries"] as? [String: Any],
              let total = int(queries["total"]),
              let blocked = int(queries["blocked"])
        else { throw PiholeProblem.notUnderstood }
        return DNSSummary(blockingEnabled: true, queriesToday: total, blockedToday: blocked)
    }

    public static func history(from data: Data, ending: Date) throws -> [DayChartSample] {
        let root = try object(data)
        guard let rows = root["history"] as? [[String: Any]] else {
            throw PiholeProblem.notUnderstood
        }
        let points = rows.compactMap { row -> HistoryPoint? in
            guard let timestamp = double(row["timestamp"]),
                  let total = int(row["total"]),
                  let blocked = int(row["blocked"])
            else { return nil }
            return HistoryPoint(timestamp: timestamp, total: total, blocked: blocked)
        }
        return DayChartBuilder.hours(from: points, ending: ending)
    }

    public static func blocking(from data: Data) throws -> DNSBlocking {
        let root = try object(data)
        guard let word = root["blocking"] as? String else { throw PiholeProblem.notUnderstood }
        if word == "enabled" {
            return DNSBlocking(enabled: true)
        }
        let timer = int(root["timer"])
        let pause = timer.flatMap { PauseLength(seconds: $0) }
        return DNSBlocking(enabled: false, pause: pause)
    }

    public static func namedCounts(
        from data: Data,
        listKey: String,
        nameKey: String,
        fallbackNameKey: String? = nil
    ) throws -> [DNSCount] {
        let root = try object(data)
        guard let rows = root[listKey] as? [[String: Any]] else { throw PiholeProblem.notUnderstood }
        return rows.compactMap { row in
            let name = text(row[nameKey]) ?? fallbackNameKey.flatMap { text(row[$0]) }
            guard let name, let count = int(row["count"]) else { return nil }
            return DNSCount(name: name, count: count)
        }
    }

    public static func queries(from data: Data) throws -> [DNSQuery] {
        let root = try object(data)
        guard let rows = root["queries"] as? [[String: Any]] else { throw PiholeProblem.notUnderstood }
        return rows.compactMap { row in
            guard let domain = row["domain"] as? String else { return nil }
            let status = row["status"] as? String ?? ""
            let identifier = int(row["id"]).map(String.init) ?? domain
            let time = double(row["time"]) ?? 0
            return DNSQuery(
                id: identifier,
                domain: domain,
                client: clientName(row["client"]),
                outcome: QueryOutcomeMap.outcome(status: status),
                at: Date(timeIntervalSince1970: time)
            )
        }
    }

    public static func clients(from data: Data) throws -> [NamedRow] {
        try rows(from: data, key: "clients") { row, index in
            let name = (row["name"] as? String) ?? (row["client"] as? String) ?? "Device"
            let detail = (row["comment"] as? String) ?? "Known"
            return NamedRow(id: "\(index)", name: name, detail: detail)
        }
    }

    public static func groups(from data: Data) throws -> [NamedRow] {
        try rows(from: data, key: "groups") { row, index in
            let name = (row["name"] as? String) ?? "Group"
            let detail = (row["comment"] as? String) ?? "Devices that share a rule"
            return NamedRow(id: "\(index)", name: name, detail: detail)
        }
    }

    public static func lists(from data: Data) throws -> [DNSListRow] {
        try rows(from: data, key: "lists") { row, index in
            let address = (row["address"] as? String) ?? "fixture.local"
            let name = (row["comment"] as? String) ?? address
            let enabled = (row["enabled"] as? Bool) ?? true
            return DNSListRow(id: "\(index)", name: name, host: host(from: address), enabled: enabled)
        }
    }

    public static func hosts(from data: Data) throws -> [NamedRow] {
        try stringRows(from: data, keys: ["hosts"]) { line, index in
            let parts = line.split(separator: " ")
            let name = parts.count > 1 ? String(parts[1]) : line
            return NamedRow(id: "host-\(index)", name: name, detail: "Inside the house")
        }
    }

    public static func domainRows(from data: Data, detail: String) throws -> [NamedRow] {
        try rows(from: data, key: "domains") { row, index in
            let name = text(row["domain"]) ?? text(row["unicode"]) ?? "A name"
            let enabled = (row["enabled"] as? Bool) ?? true
            let note = enabled ? detail : "\(detail), off"
            return NamedRow(id: "\(detail)-\(index)", name: name, detail: note)
        }
    }

    public static func queryLogging(from data: Data) throws -> Bool {
        let wire = try JSONDecoder().decode(QueryLoggingWire.self, from: data)
        if let value = wire.queryLogging ?? wire.config?.dns?.queryLogging {
            return value
        }
        throw PiholeProblem.notUnderstood
    }

    public static func summaryFacts(from data: Data) throws -> PiholeSummaryFacts {
        let root = try object(data)
        guard let queries = root["queries"] as? [String: Any],
              let total = int(queries["total"]),
              let blocked = int(queries["blocked"])
        else { throw PiholeProblem.notUnderstood }
        let clients = root["clients"] as? [String: Any]
        let active = int(clients?["active"]) ?? 0
        let gravity = root["gravity"] as? [String: Any]
        let stamp = double(gravity?["last_update"]) ?? 0
        let updated = stamp > 0 ? Date(timeIntervalSince1970: stamp) : nil
        return PiholeSummaryFacts(total: total, blocked: blocked, activeClients: active, listsUpdatedAt: updated)
    }

    public static func loginProbe(from data: Data) -> PiholeLoginProbe {
        guard let wire = try? JSONDecoder().decode(LoginWire.self, from: data),
              let dns = wire.dns
        else { return .notThisService }
        return dns ? .answering : .dnsOff
    }

    public static func cnames(from data: Data) throws -> [NamedRow] {
        try stringRows(from: data, keys: ["cnameRecords"]) { line, index in
            let parts = line.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            let name = parts.first ?? line
            let detail = parts.count > 1 ? parts[1] : "Another name"
            return NamedRow(id: "cname-\(index)", name: name, detail: detail)
        }
    }

    private static func rows<Row>(
        from data: Data,
        key: String,
        map: ([String: Any], Int) -> Row
    ) throws -> [Row] {
        let root = try object(data)
        guard let list = root[key] as? [[String: Any]] else { throw PiholeProblem.notUnderstood }
        return list.enumerated().map { map($1, $0) }
    }

    private static func stringRows(
        from data: Data,
        keys: [String],
        map: (String, Int) -> NamedRow
    ) throws -> [NamedRow] {
        let lines = try stringList(data, keys: keys)
        return lines.enumerated().map { map($1, $0) }
    }

    private static func stringList(_ data: Data, keys: [String]) throws -> [String] {
        let value = try JSONSerialization.jsonObject(with: data)
        if let lines = value as? [String] {
            return lines
        }
        guard let root = value as? [String: Any] else { throw PiholeProblem.notUnderstood }
        for key in keys {
            if let lines = root[key] as? [String] {
                return lines
            }
        }
        if let config = root["config"] as? [String: Any],
           let dns = config["dns"] as? [String: Any] {
            for key in keys {
                if let lines = dns[key] as? [String] {
                    return lines
                }
            }
        }
        throw PiholeProblem.notUnderstood
    }

    private static func object(_ data: Data) throws -> [String: Any] {
        let value = try JSONSerialization.jsonObject(with: data)
        guard let root = value as? [String: Any] else { throw PiholeProblem.notUnderstood }
        return root
    }

    private static func text(_ value: Any?) -> String? {
        guard let value = value as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func clientName(_ value: Any?) -> String {
        if let name = value as? String, !name.isEmpty {
            return name
        }
        if let object = value as? [String: Any], let name = object["name"] as? String, !name.isEmpty {
            return name
        }
        return "A device"
    }

    private static func host(from address: String) -> String {
        if let url = URL(string: address), let host = url.host {
            return host
        }
        return address
    }

    private static func int(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? Double { return Int(value) }
        if let value = value as? NSNumber { return value.intValue }
        return nil
    }

    private static func double(_ value: Any?) -> Double? {
        if let value = value as? Double { return value }
        if let value = value as? Int { return Double(value) }
        if let value = value as? NSNumber { return value.doubleValue }
        return nil
    }
}

private struct LoginWire: Decodable {
    var dns: Bool?
}

private struct QueryLoggingWire: Decodable {
    struct DNS: Decodable {
        var queryLogging: Bool?
    }

    struct Config: Decodable {
        var dns: DNS?
    }

    var queryLogging: Bool?
    var config: Config?
}
