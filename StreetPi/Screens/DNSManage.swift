import SwiftUI
import StreetPiCore

struct ReadOnlyRows: View {
    var title: String
    var intro: String
    var rows: [NamedRow]
    var notice: String?
    var theme: StreetTheme
    var wide: Bool

    var body: some View {
        ControlScreen(wide: wide) {
            ControlTitle(title: title, line: intro, theme: theme)
            if let notice {
                Text(notice)
                    .font(.subheadline)
                    .foregroundStyle(theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ControlGrid {
                ForEach(rows) { row in
                    PlainTile(title: row.name, line: row.detail, theme: theme)
                }
            }
        }
    }
}

struct DomainScreen: View {
    var domains: [NamedRow]
    var theme: StreetTheme
    var wide: Bool
    var onAction: (HouseholdAction) -> Void

    @State private var editing = false

    var body: some View {
        ControlScreen(wide: wide) {
            ControlTitle(title: "Domains", line: "Block or allow one name for the whole house.", theme: theme)
            Button("Block or allow a name") { editing = true }
                .font(.headline)
                .foregroundStyle(theme.accent)
                .frame(minHeight: 44, alignment: .leading)
            ControlGrid {
                ForEach(domains) { row in
                    PlainTile(title: row.name, line: row.detail, theme: theme)
                }
            }
        }
        .sheet(isPresented: $editing) {
            DomainEditor(theme: theme, onAction: onAction)
        }
    }
}

struct LocalNamesScreen: View {
    var hosts: [NamedRow]
    var cnames: [NamedRow]
    var theme: StreetTheme
    var wide: Bool

    var body: some View {
        ControlScreen(wide: wide) {
            ControlTitle(title: "Local names", line: DNSCopy.localNamesNote, theme: theme)
            nameSection("Addresses", rows: hosts)
            nameSection("Other names", rows: cnames)
        }
    }

    @ViewBuilder
    private func nameSection(_ title: String, rows: [NamedRow]) -> some View {
        if rows.isEmpty == false {
            ControlSection(title: title, theme: theme)
            ControlGrid {
                ForEach(rows) { row in
                    PlainTile(title: row.name, line: row.detail, theme: theme)
                }
            }
        }
    }
}

struct ListScreen: View {
    var lists: [DNSListRow]
    var theme: StreetTheme
    var wide: Bool

    var body: some View {
        ControlScreen(wide: wide) {
            ControlTitle(
                title: "Block lists",
                line: "Lists the filter uses. This phone does not add, remove, or turn them off.",
                theme: theme
            )
            ControlGrid {
                ForEach(lists) { list in
                    NumberTile(
                        label: list.name,
                        number: list.statusWord,
                        line: list.host,
                        theme: theme
                    )
                }
            }
        }
    }
}

struct DNSUpkeep: View {
    var desk: DNSDesk
    var theme: StreetTheme
    var wide: Bool
    var now: Date
    var onAction: (HouseholdAction) -> Void

    var body: some View {
        ControlScreen(wide: wide) {
            ControlTitle(title: "Upkeep", line: titleLine, theme: theme)
            Text(desk.upkeepNote ?? DNSCopy.upkeepDetail)
                .font(.body)
                .foregroundStyle(theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                onAction(.updateBlockLists)
            } label: {
                Text("Update block lists")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(theme.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Rhythm.line)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .background(theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(theme.hairline, lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Update block lists")
            if desk.textLogKnown {
                if let note = desk.textLogReadNote {
                    PlainTile(title: note, line: LiveReadCopy.tryAgain, theme: theme)
                }
                NumberTile(
                    label: "Text log file",
                    number: desk.textLogFileEnabled ? "On" : "Off",
                    line: "Lookups are still kept.",
                    theme: theme
                )
                if desk.textLogFileEnabled {
                    Text(fileLine)
                        .font(.body)
                        .foregroundStyle(theme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else if let note = desk.textLogReadNote {
                PlainTile(title: note, line: LiveReadCopy.tryAgain, theme: theme)
            } else {
                PlainTile(
                    title: "Text log",
                    line: "The text log will show here once this phone can read it.",
                    theme: theme
                )
            }
            if desk.textLogLines.isEmpty == false {
                textLog
            }
        }
    }

    private var titleLine: String {
        guard desk.listsUpdateKnown else {
            return "The filter's lists and the text log."
        }
        return "Lists updated \(AgePhrase.english(from: desk.listsUpdatedAt, to: now))."
    }

    private var fileLine: String {
        if desk.textLogFileEnabled {
            return "The text log file is on. This phone does not change settings on the Pi."
        }
        return DNSCopy.upkeepDetail
    }

    private var textLog: some View {
        VStack(alignment: .leading, spacing: Rhythm.line) {
            Text("Text log")
                .font(.headline)
                .foregroundStyle(theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            ForEach(Array(desk.textLogLines.enumerated()), id: \.offset) { _, line in
                Text(line.replacingOccurrences(of: ".", with: ".\u{200B}"))
                    .font(.subheadline)
                    .foregroundStyle(theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .controlPlate(theme: theme)
    }
}
