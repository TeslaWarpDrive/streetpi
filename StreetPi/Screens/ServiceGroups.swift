import StreetPiCore
import SwiftUI

/// Group headings describe what each service does for the house.
struct ServiceGroups: View {
    var rows: [NamedRow]

    private let headings = ["Ad blocker", "Streaming", "Remote help", "Smart home", "Internet", "Other services"]

    var body: some View {
        VStack(alignment: .leading, spacing: AfterglowShape.block) {
            ForEach(headings, id: \.self) { heading in
                let members = rows.filter { Self.heading(for: $0.name) == heading }
                if !members.isEmpty {
                    VStack(alignment: .leading, spacing: AfterglowShape.line) {
                        KickerLabel(text: heading)
                        StatusList(lines: members.map(Self.line), mark: .dot)
                    }
                }
            }
        }
    }

    private static func line(_ row: NamedRow) -> StatusLine {
        StatusLine(id: row.id, name: row.name, word: row.detail, tone: StatusLine.tone(forWord: row.detail))
    }

    private static func heading(for name: String) -> String {
        let name = name.lowercased()
        if name.contains("pi-hole") || name.contains("pihole") || name.contains("unbound")
            || name == "ad blocker" || name == "name lookup" {
            return "Ad blocker"
        }
        if name.contains("mediaflow") || name.contains("caddy") {
            return "Streaming"
        }
        if name.contains("rustdesk") {
            return "Remote help"
        }
        if name.contains("home assistant") || name.contains("matter") || name == "house controls" {
            return "Smart home"
        }
        if name.contains("duckdns") || name.contains("address") {
            return "Internet"
        }
        return "Other services"
    }
}
