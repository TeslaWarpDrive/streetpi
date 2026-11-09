import Foundation

/// Whether the setup form is on screen. It follows the saved password and the ask.
/// The Ad blocker tab is the only presenter. Clients and Settings navigate there.
public enum SetupCover: Equatable, Sendable {
    /// The form stays off the screen.
    case hidden
    /// The Ad blocker tab is showing the form. `replacing` is true when a password is already saved.
    case showing(replacing: Bool)

    /// Who may present the form.
    public enum Presenter: Equatable, Sendable, CaseIterable {
        case adBlockerTab
    }

    /// Where the person asked. The Ad blocker tab is already showing that page.
    public enum Ask: Equatable, Sendable, CaseIterable {
        case adBlockerTab
        case clients
        case settings
    }

    /// What the ask should do. Opening the tab and showing the form are separate.
    public struct Request: Equatable, Sendable {
        public var openAdBlockerTab: Bool
        public var showForm: Bool
    }

    /// The cover has one owner.
    public static let presenters: [Presenter] = Presenter.allCases

    public init(passwordSaved: Bool, userAsked: Bool) {
        if userAsked {
            self = .showing(replacing: passwordSaved)
        } else {
            self = .hidden
        }
    }

    public var isShowing: Bool {
        if case .showing = self { return true }
        return false
    }

    /// A phone with no saved password can offer setup. Replacing a saved password is a separate ask.
    public static func offersSetup(passwordSaved: Bool) -> Bool {
        passwordSaved == false
    }

    /// Clients and Settings open the Ad blocker tab first. That tab only shows the form.
    public static func request(from ask: Ask) -> Request {
        switch ask {
        case .adBlockerTab:
            Request(openAdBlockerTab: false, showForm: true)
        case .clients, .settings:
            Request(openAdBlockerTab: true, showForm: true)
        }
    }
}
