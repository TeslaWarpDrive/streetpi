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
        DeskScroll(wide: wide) {
            heading
            if let notice {
                Text(notice)
                    .font(.subheadline)
                    .foregroundStyle(theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(rows) { row in
                DeskCard(theme: theme) {
                    Text(row.name)
                        .font(.headline)
                        .foregroundStyle(theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(row.detail)
                        .font(.subheadline)
                        .foregroundStyle(theme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: Rhythm.tight) {
            Text(title)
                .font(.system(.largeTitle, design: .rounded))
                .foregroundStyle(theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(intro)
                .font(.body)
                .foregroundStyle(theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct DomainScreen: View {
    var domains: [NamedRow]
    var theme: StreetTheme
    var wide: Bool
    var onAction: (HouseholdAction) -> Void

    @State private var draft = ""

    var body: some View {
        DeskScroll(wide: wide) {
            Text("Domains")
                .font(.system(.largeTitle, design: .rounded))
                .foregroundStyle(theme.ink)
                .accessibilityAddTraits(.isHeader)
            Text("Block one name, or allow one name, for the whole house.")
                .font(.body)
                .foregroundStyle(theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(domains) { row in
                DeskCard(theme: theme) {
                    Text(row.name)
                        .font(.headline)
                        .foregroundStyle(theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(row.detail)
                        .font(.subheadline)
                        .foregroundStyle(theme.secondary)
                }
            }
            editor
        }
    }

    private var trimmed: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var editor: some View {
        DeskCard(theme: theme) {
            TextField("A domain name", text: $draft)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.body)
                .foregroundStyle(theme.ink)
            Button("Block") {
                submit(blocked: true)
            }
            .font(.body.weight(.semibold))
            .foregroundStyle(trimmed.isEmpty ? theme.tertiary : theme.accent)
            .disabled(trimmed.isEmpty)
            Button("Allow") {
                submit(blocked: false)
            }
            .font(.body.weight(.semibold))
            .foregroundStyle(trimmed.isEmpty ? theme.tertiary : theme.accent)
            .disabled(trimmed.isEmpty)
        }
    }

    private func submit(blocked: Bool) {
        let name = trimmed
        guard !name.isEmpty else { return }
        draft = ""
        if blocked {
            onAction(.blockDomain(named: name))
        } else {
            onAction(.allowDomain(named: name))
        }
    }
}

struct LocalNamesScreen: View {
    var hosts: [NamedRow]
    var cnames: [NamedRow]
    var theme: StreetTheme
    var wide: Bool

    var body: some View {
        DeskScroll(wide: wide) {
            Text("Local names")
                .font(.system(.largeTitle, design: .rounded))
                .foregroundStyle(theme.ink)
                .accessibilityAddTraits(.isHeader)
            Text(DNSCopy.localNamesNote)
                .font(.body)
                .foregroundStyle(theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
            section("Addresses", rows: hosts)
            section("Other names", rows: cnames)
        }
    }

    private func section(_ title: String, rows: [NamedRow]) -> some View {
        VStack(alignment: .leading, spacing: Rhythm.line) {
            Text(title)
                .font(.headline)
                .foregroundStyle(theme.ink)
                .accessibilityAddTraits(.isHeader)
            ForEach(rows) { row in
                DeskCard(theme: theme) {
                    Text(row.name)
                        .font(.headline)
                        .foregroundStyle(theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(row.detail)
                        .font(.subheadline)
                        .foregroundStyle(theme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
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
        DeskScroll(wide: wide) {
            Text("Block lists")
                .font(.system(.largeTitle, design: .rounded))
                .foregroundStyle(theme.ink)
                .accessibilityAddTraits(.isHeader)
            Text("Lists the filter uses. This phone does not add, remove, or turn them off.")
                .font(.body)
                .foregroundStyle(theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(lists) { list in
                DeskCard(theme: theme) {
                    Text(list.name)
                        .font(.headline)
                        .foregroundStyle(theme.ink)
                    Text("\(list.host) · \(list.statusWord)")
                        .font(.subheadline)
                        .foregroundStyle(theme.secondary)
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
        DeskScroll(wide: wide) {
            Text("Upkeep")
                .font(.system(.largeTitle, design: .rounded))
                .foregroundStyle(theme.ink)
                .accessibilityAddTraits(.isHeader)
            if desk.listsUpdateKnown {
                Text("Lists updated \(AgePhrase.english(from: desk.listsUpdatedAt, to: now)).")
                    .font(.body)
                    .foregroundStyle(theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
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
                    Text(note)
                        .font(.body)
                        .foregroundStyle(theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(LiveReadCopy.tryAgain)
                        .font(.subheadline)
                        .foregroundStyle(theme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if desk.textLogFileEnabled {
                    Text(fileLine)
                        .font(.body)
                        .foregroundStyle(theme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                fileCard
            } else if let note = desk.textLogReadNote {
                Text(note)
                    .font(.body)
                    .foregroundStyle(theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(LiveReadCopy.tryAgain)
                    .font(.subheadline)
                    .foregroundStyle(theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("The text log will show here once this phone can read it.")
                    .font(.body)
                    .foregroundStyle(theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !desk.textLogLines.isEmpty {
                textLog
            }
        }
    }

    private var fileCard: some View {
        DeskCard(theme: theme) {
            Text("Text log file")
                .font(.headline)
                .foregroundStyle(theme.ink)
            Text(desk.textLogFileEnabled ? "On" : "Off")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.ink)
            Text("Lookups are still kept.")
                .font(.subheadline)
                .foregroundStyle(theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var fileLine: String {
        if desk.textLogFileEnabled {
            return "The text log file is on. This phone does not change settings on the Pi."
        }
        return DNSCopy.upkeepDetail
    }

    private var textLog: some View {
        DeskCard(theme: theme) {
            Text("Text log")
                .font(.headline)
                .foregroundStyle(theme.ink)
                .accessibilityAddTraits(.isHeader)
            ForEach(Array(desk.textLogLines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(.subheadline)
                    .foregroundStyle(theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
