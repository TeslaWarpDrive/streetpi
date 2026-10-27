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

    var onAction: (HouseholdAction) -> Void = { _ in }

    /// The shared ad blocker view first, then the rest of the ad blocker pages.
    var body: some View {
        AfterglowScope(paintsGround: false) {
            AdBlockerOverview(desk: desk, theme: theme, wide: wide, onAction: onAction) {
                ControlSection(title: "More", theme: theme)
                    .padding(.top, Rhythm.line)
                ControlGrid {
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
