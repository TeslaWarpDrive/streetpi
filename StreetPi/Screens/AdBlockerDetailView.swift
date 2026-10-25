import StreetPiCore
import SwiftUI

/// Ad blocker detail. Query log, clients, and lists stay on their own pages.
struct AdBlockerDetailView: View {
    var reading: HomeAdBlockerReading
    var wide: Bool
    var passwordSaved: Bool
    var sessionActive: Bool
    var onAction: (HouseholdAction) -> Void
    var showsDirectoryLink: Bool
    var onDirectory: () -> Void
    var onSavePassword: () -> Void
    var onSignOut: () -> Void

    @Environment(\.afterglowPalette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showsExplainer = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AfterglowShape.block) {
                hero
                meaning
                stats
                AdBlockerPauseBar(blockingOn: reading.isOn, onAction: onAction)
                StoppedHourChart(hours: reading.hourlyStopped)
                if passwordSaved == false || sessionActive {
                    phoneNote
                }
                if showsDirectoryLink {
                    Button("Query log, clients, and lists", action: onDirectory)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(palette.accent)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
            }
            .padding(.horizontal, AfterglowShape.page)
            .padding(.vertical, AfterglowShape.block)
            .frame(maxWidth: wide ? 880 : 560)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .sheet(isPresented: $showsExplainer) {
            AdBlockerExplainer(reading: reading)
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: AfterglowShape.line) {
            heroNumbers
            Text(reading.fractionLine)
                .font(.body)
                .foregroundStyle(palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .contain)
    }

    private var heroNumbers: some View {
        let ring = RingArc(
            fraction: reading.ringFraction,
            diameter: dynamicTypeSize.isAccessibilitySize ? 120 : 96
        )
        let words = VStack(alignment: .leading, spacing: 4) {
            Text(reading.percentText)
                .font(.largeTitle.bold())
                .foregroundStyle(palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(reading.blockingLine)
                .font(.title3)
                .foregroundStyle(palette.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        let info = IconChromeButton(title: "What the percent means", systemImage: "info.circle") {
            showsExplainer = true
        }
        return ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: AfterglowShape.line) {
                ring
                words
                Spacer(minLength: AfterglowShape.line)
                info
            }
            VStack(alignment: .leading, spacing: AfterglowShape.line) {
                info
                ring
                words
            }
        }
    }

    private var meaning: some View {
        VStack(alignment: .leading, spacing: AfterglowShape.line) {
            Text("What this means")
                .font(.headline)
                .foregroundStyle(palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            meaningRow("Lookups", reading.lookupsText)
            meaningRow("Stopped", reading.blockedText)
            Text(reading.fractionLine)
                .font(.body)
                .foregroundStyle(palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func meaningRow(_ title: String, _ value: String) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(palette.secondary)
                Spacer(minLength: AfterglowShape.line)
                Text(value)
                    .font(.title2.bold())
                    .foregroundStyle(palette.ink)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(palette.secondary)
                Text(value)
                    .font(.title2.bold())
                    .foregroundStyle(palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var stats: some View {
        AfterglowTileGrid(
            spacing: AfterglowShape.line,
            minimumColumnWidth: dynamicTypeSize.isAccessibilitySize ? 10_000 : 160,
            maximumColumns: dynamicTypeSize.isAccessibilitySize ? 1 : 3
        ) {
            HomeFactCard(
                title: "Stopped",
                value: reading.blockedText,
                line: reading.stoppedLine,
                spoken: "Stopped, \(reading.blockedText). \(reading.stoppedLine)",
                action: nil
            )
            HomeFactCard(
                title: "Lookups",
                value: reading.lookupsText,
                line: reading.lookupsLine,
                spoken: "Lookups, \(reading.lookupsText). \(reading.lookupsLine)",
                action: nil
            )
            HomeFactCard(
                title: "Last hour",
                value: reading.lastHourText,
                line: reading.lastHourLine,
                spoken: "Last hour, \(reading.lastHourText). \(reading.lastHourLine)",
                action: nil
            )
        }
    }

    private var phoneNote: some View {
        VStack(alignment: .leading, spacing: AfterglowShape.line) {
            Text("This phone")
                .font(.headline)
                .foregroundStyle(palette.ink)
            Text(passwordSaved ? "The app password is saved on this phone." : "Not set up on this phone yet.")
                .font(.subheadline)
                .foregroundStyle(palette.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if passwordSaved == false {
                Button("Set up this phone", action: onSavePassword)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(palette.accent)
                    .frame(minHeight: 44, alignment: .leading)
            }
            if sessionActive {
                Button("Sign out", action: onSignOut)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(palette.accent)
                    .frame(minHeight: 44, alignment: .leading)
            }
        }
    }
}
