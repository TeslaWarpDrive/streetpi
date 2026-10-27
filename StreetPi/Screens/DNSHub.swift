import SwiftUI
import StreetPiCore

struct DNSHub: View {
    var desk: DNSDesk
    var theme: StreetTheme
    var wide: Bool
    var passwordSaved: Bool
    var sessionActive: Bool
    var onPage: (DNSPage) -> Void
    var onSavePassword: () -> Void
    var onSignOut: () -> Void

    var body: some View {
        ControlScreen(wide: wide) {
            ControlTitle(title: "Ad blocker", line: desk.blockingLine, theme: theme)
            ControlGrid {
                NumberTile(
                    label: "Queries",
                    number: desk.queriesToday.formatted(),
                    line: "Lookups the house made today.",
                    theme: theme
                )
                NumberTile(
                    label: "Blocked",
                    number: desk.blockedToday.formatted(),
                    line: "Turned away before they loaded.",
                    theme: theme
                )
                NumberTile(
                    label: "Devices",
                    number: desk.knownClients.formatted(),
                    line: "Devices the house knows.",
                    theme: theme
                )
                NumberTile(
                    label: "Lists",
                    number: desk.listCount.formatted(),
                    line: "Lists the filter uses.",
                    theme: theme
                )
            }
            phoneTile
            ForEach(DNSShelf.allCases) { shelf in
                shelfBlock(shelf)
            }
        }
    }

    @ViewBuilder
    private func shelfBlock(_ shelf: DNSShelf) -> some View {
        let pages = shelf.pages.filter { $0 != .services }
        if pages.isEmpty == false {
            ControlSection(title: shelf.title, theme: theme)
            ControlGrid {
                ForEach(pages) { page in
                    LinkTile(
                        title: page.title,
                        line: page.blurb,
                        symbol: page.symbolName,
                        theme: theme,
                        finalLineLayout: page == .upkeep ? "page-end" : nil,
                        action: { onPage(page) }
                    )
                }
            }
        }
    }

    private var phoneTile: some View {
        VStack(alignment: .leading, spacing: Rhythm.line) {
            Text(passwordSaved ? "The app password is saved on this phone." : "Not set up on this phone yet.")
                .font(.subheadline)
                .foregroundStyle(theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if !passwordSaved {
                Button("Set up this phone", action: onSavePassword)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(theme.accent)
                    .frame(minHeight: 44, alignment: .leading)
            }
            if sessionActive {
                Button("Sign out", action: onSignOut)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(theme.accent)
                    .frame(minHeight: 44, alignment: .leading)
            }
        }
        .controlPlate(theme: theme)
        .accessibilityElement(children: .contain)
    }
}
