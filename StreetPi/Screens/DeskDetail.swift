import SwiftUI
import StreetPiCore

struct DNSDeskDetail: View {
    var wide: Bool
    var splits: Bool
    var desk: DNSDesk
    var page: DNSPage?
    var showsDirectory: Bool
    var theme: StreetTheme
    var now: Date
    var passwordSaved: Bool
    var sessionActive: Bool
    var showsSetup: Bool
    var problem: PiholeProblem?
    var onPage: (DNSPage?) -> Void
    var onDirectory: () -> Void
    var onPending: (HouseholdAction?) -> Void
    var onSavePassword: () -> Void
    var onSetupSave: (String) -> Void
    var onSetupCancel: () -> Void

    var body: some View {
        if showsSetup {
            PiholeSetupView(theme: theme, wide: wide, onSave: onSetupSave, onCancel: onSetupCancel)
        } else if let problem {
            DNSProblemView(problem: problem, theme: theme, wide: wide)
        } else if wide, splits {
            split
        } else if let page {
            stacked(page)
        } else if showsDirectory {
            hub
        } else {
            detail(wide: wide)
        }
    }

    private var split: some View {
        DeskColumns(theme: theme) {
            DNSIndex(
                overviewSelected: page == nil,
                selected: page,
                theme: theme,
                passwordSaved: passwordSaved,
                sessionActive: sessionActive,
                onOverview: { onPage(nil) },
                onPage: { onPage($0) },
                onSavePassword: onSavePassword,
                onSignOut: { onPending(.signOutOfAdBlocker) }
            )
        } page: {
            if let page {
                DNSPageBody(
                    page: page,
                    desk: desk,
                    theme: theme,
                    wide: true,
                    now: now,
                    onAction: { onPending($0) }
                )
            } else {
                detail(wide: true)
            }
        }
    }

    private func stacked(_ page: DNSPage) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if wide {
                WideBack(title: "Ad blocker & DNS", theme: theme) {
                    onPage(nil)
                }
                .frame(minHeight: 44, alignment: .leading)
                .padding(.horizontal, Rhythm.page)
                .padding(.top, Rhythm.line)
            }
            DNSPageBody(
                page: page,
                desk: desk,
                theme: theme,
                wide: wide,
                now: now,
                onAction: { onPending($0) }
            )
        }
    }

    private func detail(wide: Bool) -> some View {
        AfterglowScope {
            AdBlockerDetailView(
            reading: HomeAdBlockerReading.from(desk: desk),
            wide: wide,
            passwordSaved: passwordSaved,
            sessionActive: sessionActive,
            onAction: { onPending($0) },
            showsDirectoryLink: wide == false,
            onDirectory: onDirectory,
            onSavePassword: onSavePassword,
            onSignOut: { onPending(.signOutOfAdBlocker) }
            )
        }
    }

    private var hub: some View {
        DNSHub(
            desk: desk,
            theme: theme,
            wide: wide,
            passwordSaved: passwordSaved,
            sessionActive: sessionActive,
            onPage: { onPage($0) },
            onSavePassword: onSavePassword,
            onSignOut: { onPending(.signOutOfAdBlocker) }
        )
    }
}

struct MachineDeskDetail: View {
    var wide: Bool
    var splits: Bool
    var desk: MachineDesk
    var page: MachinePage?
    var machine: MachineReading?
    var theme: StreetTheme
    var onPage: (MachinePage?) -> Void

    var body: some View {
        if wide, splits {
            DeskColumns(theme: theme) {
                MachineIndex(selected: page ?? .dashboard, theme: theme) { next in
                    onPage(next == .dashboard ? nil : next)
                }
            } page: {
                reading(page ?? .dashboard, links: false)
            }
        } else if let page {
            VStack(alignment: .leading, spacing: 0) {
                if wide {
                    WideBack(title: "Pi health", theme: theme) {
                        onPage(nil)
                    }
                    .frame(minHeight: 44, alignment: .leading)
                    .padding(.horizontal, Rhythm.page)
                    .padding(.top, Rhythm.line)
                }
                reading(page, links: true)
            }
        } else if machine != nil {
            MachineHome(desk: desk, machine: machine, theme: theme, wide: wide) { next in
                onPage(next)
            }
        }
    }

    private func reading(_ page: MachinePage, links: Bool) -> some View {
        MachinePageBody(
            page: page,
            desk: desk,
            machine: machine,
            theme: theme,
            wide: wide,
            showsDestinations: links,
            onPage: { onPage($0) }
        )
    }
}
