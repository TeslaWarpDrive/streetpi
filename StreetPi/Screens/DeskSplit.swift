import SwiftUI
import StreetPiCore

struct DeskColumns<Index: View, Page: View>: View {
    var theme: StreetTheme
    @ViewBuilder var index: Index
    @ViewBuilder var page: Page

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ScrollView {
                index
                    .padding(Rhythm.line)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
            .frame(minWidth: 216, idealWidth: 260, maxWidth: 320)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(theme.surface)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Pages")
            Rectangle()
                .fill(theme.hairline)
                .frame(width: 1)
                .frame(maxHeight: .infinity)
                .accessibilityHidden(true)
            page
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct DeskIndexButton: View {
    var title: String
    var symbol: String
    var selected: Bool
    var theme: StreetTheme
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.body.weight(selected ? .semibold : .regular))
                .foregroundStyle(selected ? theme.ink : theme.secondary)
                .labelStyle(.titleAndIcon)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .padding(.horizontal, 12)
                .background(
                    selected ? theme.background : Color.clear,
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct DNSIndex: View {
    var selected: DNSPage
    var theme: StreetTheme
    var passwordSaved: Bool
    var sessionActive: Bool
    var onPage: (DNSPage) -> Void
    var onSavePassword: () -> Void
    var onSignOut: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Rhythm.line) {
            phoneNote
            ForEach(DNSShelf.allCases) { shelf in
                VStack(alignment: .leading, spacing: Rhythm.tight) {
                    Text(shelf.title)
                        .font(.headline)
                        .foregroundStyle(theme.ink)
                        .accessibilityAddTraits(.isHeader)
                    ForEach(shelf.pages.filter { $0 != .services }) { page in
                        DeskIndexButton(
                            title: page.title,
                            symbol: page.symbolName,
                            selected: page == selected,
                            theme: theme,
                            action: { onPage(page) }
                        )
                    }
                }
            }
        }
    }

    private var phoneNote: some View {
        VStack(alignment: .leading, spacing: Rhythm.tight) {
            Text("This phone")
                .font(.headline)
                .foregroundStyle(theme.ink)
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
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MachineIndex: View {
    var selected: MachinePage
    var theme: StreetTheme
    var onPage: (MachinePage) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Rhythm.tight) {
            Text("Pi health")
                .font(.headline)
                .foregroundStyle(theme.ink)
                .accessibilityAddTraits(.isHeader)
            ForEach(MachinePage.allCases) { page in
                DeskIndexButton(
                    title: page.title,
                    symbol: page.symbolName,
                    selected: page == selected,
                    theme: theme,
                    action: { onPage(page) }
                )
            }
        }
    }
}
