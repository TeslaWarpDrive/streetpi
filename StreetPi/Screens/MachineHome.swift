import StreetPiCore
import SwiftUI

/// The Pi tab's first page: the hero, then the four rings. A ring opens its day chart.
struct MachineHome: View {
    var desk: MachineDesk
    var machine: MachineReading?
    var theme: StreetTheme
    var wide: Bool
    var showsDestinations: Bool = true
    var piNotice: String?
    var onPage: (MachinePage) -> Void

    @Environment(\.afterglowPalette) private var palette

    var body: some View {
        ControlScreen(wide: wide) {
            hero
            if machine?.hasSignal != true, let piNotice {
                Text(piNotice)
                    .font(.body)
                    .foregroundStyle(palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let machine {
                KickerLabel(text: "Right now")
                    .padding(.top, AfterglowShape.tight)
                MachineRings(machine: machine, onOpen: { onPage(.chart) })
            }
            if showsDestinations {
                KickerLabel(text: "More")
                    .padding(.top, AfterglowShape.line)
                ControlGrid {
                    ForEach(MachinePage.allCases.filter { $0 != .dashboard }) { page in
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
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: AfterglowShape.tight) {
            Text("The Pi")
                .font(AfterglowType.display)
                .foregroundStyle(palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            MonoReading(text: ReadingText.machineLine(model: desk.modelName, uptimeSeconds: machine?.uptimeSeconds))
            if !displayedHost.isEmpty {
                MonoReading(text: displayedHost)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    /// The fixture host is not a machine the house can open.
    private var displayedHost: String {
        let host = desk.host.trimmingCharacters(in: .whitespacesAndNewlines)
        if host.isEmpty || host == "fixture.local" { return "" }
        return host
    }
}
