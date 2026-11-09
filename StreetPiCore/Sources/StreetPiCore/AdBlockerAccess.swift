import Foundation

/// The ad blocker page on this phone: the password, sign-out, and the certificate pin.
/// The probe, the board, and the root used to decide this separately. One reduce owns it.
public struct AdBlockerAccess: Sendable, Equatable {
    public enum Phase: Sendable, Equatable {
        /// No app password is saved on this phone.
        case noPassword
        /// The person signed out. The screen says this phone will ask again.
        case signedOut
        /// A read can show the desk.
        case ready
        /// A new certificate is on screen. The value is the pin that caused it.
        case certificateChanged(String)
        /// The person kept the saved pin.
        case pinKept
        /// Some other problem is on screen.
        case blocked(PiholeProblem)
    }

    public enum Event: Sendable, Equatable {
        case passwordSaved
        /// Saving the ad blocker address and pin in Settings.
        case settingsSaved
        case signOut
        /// The home probe stored a pin. Nil means this probe had nothing to show.
        case probePresented(pin: String?)
        case keptPin
        case trustedPin
        /// `problem` is nil when the board read clearly. `readPin` is the pin that read offered.
        case boardReported(problem: PiholeProblem?, readPin: String?)
        case roadChanged(ConnectionMode)
    }

    public private(set) var passwordSaved: Bool
    public private(set) var signedOut: Bool
    /// The pin from the home probe.
    public private(set) var probePin: String?
    /// The pin from a later ad blocker read.
    public private(set) var readPin: String?
    public private(set) var declinedPin: String?
    public private(set) var dnsProblem: PiholeProblem?
    public private(set) var road: ConnectionMode
    /// A clear away-live read has happened since the last probe or sign-out.
    /// While the road stays away-live, the home probe's pin does not cover that read.
    /// Home, offline, and the mailbox ignore this and still show the pin.
    public private(set) var homeProbeYields: Bool

    public init(
        passwordSaved: Bool = false,
        signedOut: Bool = false,
        probePin: String? = nil,
        readPin: String? = nil,
        declinedPin: String? = nil,
        dnsProblem: PiholeProblem? = nil,
        road: ConnectionMode = .home,
        homeProbeYields: Bool = false
    ) {
        self.passwordSaved = passwordSaved
        self.signedOut = signedOut
        self.probePin = probePin
        self.readPin = readPin
        self.declinedPin = declinedPin
        self.dnsProblem = dnsProblem
        self.road = road
        self.homeProbeYields = homeProbeYields
    }

    public func reduce(_ event: Event) -> AdBlockerAccess {
        var next = self
        switch event {
        case .passwordSaved:
            next.passwordSaved = true
            next.signedOut = false
        case .settingsSaved:
            next.signedOut = false
        case .signOut:
            next.signedOut = true
            next.dnsProblem = .needsSignIn
            next.readPin = nil
            next.homeProbeYields = false
        case .probePresented(let pin):
            next.probePin = pin
            next.homeProbeYields = false
        case .keptPin:
            next.keepPin()
        case .trustedPin:
            next.declinedPin = nil
            next.probePin = nil
            next.readPin = nil
            next.signedOut = false
            next.homeProbeYields = false
        case .boardReported(let problem, let readPin):
            next.noteBoard(problem, readPin: readPin)
        case .roadChanged(let road):
            next.road = road
        }
        return next
    }

    /// What the Ad blocker tab shows. A probe pin wins, except a clear away-live read.
    /// The mailbox hides the board problem and does not hide a probe pin.
    public var displayedDNSProblem: PiholeProblem? {
        if let covered = coveredProbeProblem { return covered }
        if case .awayMailbox = road { return nil }
        return dnsProblem
    }

    public var phase: Phase {
        switch displayedDNSProblem {
        case .certificateChanged:
            return .certificateChanged(certificatePin)
        case .pinKept:
            return .pinKept
        case .needsSignIn where signedOut:
            return .signedOut
        case let problem?:
            if passwordSaved == false, problem == .notSetUp || problem == .needsPassword {
                return .noPassword
            }
            return .blocked(problem)
        case nil:
            if passwordSaved == false { return .noPassword }
            if signedOut { return .signedOut }
            return .ready
        }
    }

    /// Sign-out leaves the latch set. The watch still asks the ad blocker again.
    public var watchRefuses: Bool { false }

    /// Sign-out leaves the latch set. Pull to refresh still asks the ad blocker again.
    public var refreshRefuses: Bool { false }

    private var certificatePin: String {
        if let probePin, probePinCovers { return probePin }
        return readPin ?? probePin ?? ""
    }

    private var probePinCovers: Bool {
        guard probePin != nil else { return false }
        if homeProbeYields, case .awayLive = road { return false }
        return true
    }

    /// Nil when the pin matches on an away road, so the board problem can show.
    private var coveredProbeProblem: PiholeProblem? {
        guard let probePin, probePinCovers else { return nil }
        guard probePin == declinedPin else { return .certificateChanged }
        switch road {
        case .home, .offline:
            return .pinKept
        case .awayLive, .awayMailbox:
            return nil
        }
    }

    private mutating func keepPin() {
        declinedPin = probePin ?? readPin ?? declinedPin
        switch road {
        case .awayLive, .awayMailbox:
            if dnsProblem == .certificateChanged || dnsProblem == .pinKept {
                dnsProblem = nil
            }
        case .home, .offline:
            dnsProblem = .pinKept
            readPin = nil
        }
    }

    private mutating func noteBoard(_ problem: PiholeProblem?, readPin: String?) {
        dnsProblem = problem
        self.readPin = problem == .certificateChanged ? readPin : nil
        if case .awayLive = road, problem == nil, probePin != nil {
            homeProbeYields = true
        } else {
            homeProbeYields = false
        }
    }
}
