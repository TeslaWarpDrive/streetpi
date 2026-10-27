import SwiftUI

/// The same four destinations as the phone, opened as a regular-width sidebar.
struct ShellSidebar: View {
    @Binding var selection: HouseTab?
    var theme: StreetTheme

    var body: some View {
        List(selection: $selection) {
            ForEach(HouseTab.allCases) { tab in
                Label(tab.title, systemImage: tab.symbol)
                    .tag(Optional(tab))
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(theme.surface.ignoresSafeArea())
        .navigationTitle("Pi Stats")
    }
}
