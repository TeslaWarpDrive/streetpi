import SwiftUI
import StreetPiCore

private let minimumDeskSplitWidth: CGFloat = 720

struct DNSDeskDetail: View {
    var wide: Bool
    var splits: Bool
    var desk: DNSDesk
    var page: DNSPage?
    var theme: StreetTheme
    var now: Date
    var passwordSaved: Bool
    var sessionActive: Bool
    var cover: SetupCover
    var problem: PiholeProblem?
    var trustNote: String?
    var onTrustNewCertificate: () -> Void = {}
    var onKeepSavedPin: () -> Void = {}
    var actionNotice: ActionNotice?
    var onPage: (DNSPage?) -> Void
    var onPending: (HouseholdAction?) -> Void
    var onSavePassword: () -> Void
    var onSetupSave: (String) -> Void
    var onSetupCancel: () -> Void

    @Environment(\.streetPiStill) private var still

    var body: some View {
        // The Ad blocker tab is the only setup presenter. Clients and Settings open this tab.
        if cover.isShowing {
            if still {
                setup
            } else {
                Color.clear
                    .sheet(isPresented: .constant(true)) {
                        setup
                            .presentationDragIndicator(.visible)
                            .presentationBackground(theme.background)
                            .interactiveDismissDisabled()
                    }
            }
        } else if let problem {
            DNSProblemView(
                problem: problem,
                theme: theme,
                wide: wide,
                offersSetup: SetupCover.offersSetup(passwordSaved: passwordSaved),
                onSavePassword: onSavePassword,
                onTrustNewCertificate: onTrustNewCertificate,
                onKeepSavedPin: onKeepSavedPin
            )
        } else {
            deskBody
                .environment(\.dnsActionNotice, actionNotice)
        }
    }

    private var setup: some View {
        PiholeSetupView(
            theme: theme,
            wide: wide,
            trustNote: trustNote,
            onSave: onSetupSave,
            onCancel: onSetupCancel
        )
    }

    @ViewBuilder
    private var deskBody: some View {
        if wide, splits {
            ViewThatFits(in: .horizontal) {
                split.frame(minWidth: minimumDeskSplitWidth)
                singleColumn
            }
        } else {
            singleColumn
        }
    }

    @ViewBuilder
    private var singleColumn: some View {
        if let page {
            stacked(page)
        } else {
            hub
        }
    }

    private var split: some View {
        DeskColumns(theme: theme) {
            DNSIndex(
                selected: page ?? .today,
                theme: theme,
                passwordSaved: passwordSaved,
                sessionActive: sessionActive,
                onPage: { onPage($0) },
                onSavePassword: onSavePassword,
                onSignOut: { onPending(.signOutOfAdBlocker) }
            )
        } page: {
            DNSPageBody(
                page: page ?? .today,
                desk: desk,
                theme: theme,
                wide: true,
                now: now,
                onAction: { onPending($0) }
            )
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

    private var hub: some View {
        DNSHub(
            desk: desk,
            theme: theme,
            wide: wide,
            passwordSaved: passwordSaved,
            sessionActive: sessionActive,
            onPage: { onPage($0) },
            onSavePassword: onSavePassword,
            onSignOut: { onPending(.signOutOfAdBlocker) },
            onAction: { onPending($0) }
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
    var piNotice: String?
    var onPage: (MachinePage?) -> Void

    /// Every Pi page reads the Aurora palette and motion gate. The tab paints its own ground.
    var body: some View {
        AfterglowScope(paintsGround: false) {
            pages
        }
    }

    @ViewBuilder
    private var pages: some View {
        if wide, splits {
            ViewThatFits(in: .horizontal) {
                split.frame(minWidth: minimumDeskSplitWidth)
                singleColumn
            }
        } else {
            singleColumn
        }
    }

    private var split: some View {
        DeskColumns(theme: theme) {
            MachineIndex(selected: page ?? .dashboard, theme: theme) { next in
                onPage(next == .dashboard ? nil : next)
            }
        } page: {
            reading(page ?? .dashboard, links: false)
        }
    }

    @ViewBuilder
    private var singleColumn: some View {
        if let page {
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
        } else {
            MachineHome(desk: desk, machine: machine, theme: theme, wide: wide, piNotice: piNotice) { next in
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
            piNotice: piNotice,
            onPage: { onPage($0) }
        )
    }
}
