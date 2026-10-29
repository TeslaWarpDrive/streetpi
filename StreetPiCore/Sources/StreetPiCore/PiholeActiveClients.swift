import Foundation

extension PiholeDecode {
    public static func activeClients(from data: Data) throws -> [NamedRow] {
        let root = try JSONSerialization.jsonObject(with: data)
        guard let object = root as? [String: Any],
              let clients = object["clients"] as? [[String: Any]] else { throw PiholeProblem.notUnderstood }
        return try clients.map { client in
            guard let ip = client["ip"] as? String, !ip.isEmpty,
                  let count = client["count"] as? Int else { throw PiholeProblem.notUnderstood }
            let name = (client["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return NamedRow(
                id: ip, name: name.flatMap { $0.isEmpty ? nil : $0 } ?? ip,
                detail: "\(ip) · \(count.formatted()) \(count == 1 ? "lookup" : "lookups")"
            )
        }
    }
}
