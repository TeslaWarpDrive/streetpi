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

    public static func namedCounts(from data: Data, listKey: String, nameKey: String) throws -> [DNSCount] {
        let root = try object(data)
        guard let rows = root[listKey] as? [[String: Any]] else { throw PiholeProblem.notUnderstood }
        return rows.compactMap { row in
            guard let name = row[nameKey] as? String, let count = int(row["count"]) else { return nil }
            return DNSCount(name: name, count: count)
        }
    }

    public static func textLog(from data: Data) throws -> TextLogPage {
        let root = try object(data)
        let next = int(root["nextID"]) ?? 0
        let pid = int(root["pid"])
        let file = root["file"] as? String
        return TextLogPage(
            lines: try logLines(root["log"]),
            nextID: next,
            pid: pid,
            fileEnabled: fileIsOn(file)
        )
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

    private static func logLines(_ value: Any?) throws -> [String] {
        if let rows = value as? [String] {
            return rows.map(cleanLine).filter { !$0.isEmpty }
        }
        guard let rows = value as? [[String: Any]] else { throw PiholeProblem.notUnderstood }
        return rows.compactMap { row in
            guard let message = row["message"] as? String else { return nil }
            let cleaned = cleanLine(message)
            return cleaned.isEmpty ? nil : cleaned
        }
    }

    private static func cleanLine(_ line: String) -> String {
        line.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func fileIsOn(_ file: String?) -> Bool {
        guard let file else { return false }
        let word = file.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if word.isEmpty || word == "none" || word == "null" || word == "/dev/null" {
            return false
        }
        return true
    }

    private static func object(_ data: Data) throws -> [String: Any] {
        let value: Any
        do {
            value = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw PiholeProblem.notUnderstood
        }
        guard let root = value as? [String: Any] else { throw PiholeProblem.notUnderstood }
        return root
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
