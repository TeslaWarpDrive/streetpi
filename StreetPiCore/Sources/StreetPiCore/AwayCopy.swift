import Foundation

/// Plain words for Away mode. No name, address, or number from the house is ever in here.
public enum AwayCopy {
    public static let onlyAtHomeTitle = "Only at home"
    public static let onlyAtHomeDetail = "This part stays private, so it opens when you're back on the home Wi-Fi."
    public static let pauseDetail = "Pausing and turning ad blocking back on work when you're on the home Wi-Fi."
    public static let chartWaiting = "The day's chart arrives with the Pi's next report."
    public static let chartWaitingTitle = "The day's chart is on its way."
    public static let alertsAtHome = "Alerts are read from the Pi, so they show when you're home."
    public static let noMeters = "The Pi couldn't read its meters for this report."
    public static let noChecks = "The Pi couldn't read its checks."
    public static let notInReport = "Not in the away report."
    public static let notSure = "The Pi isn't sure if ad blocking is on."
    public static let noBackupWord = "The Pi can't tell from here."
    public static let backupFailed = "The last backup did not finish."
    public static let quietHeadline = "No word from the Pi."
    public static let tapToOpen = "Tap a tile to open it."
    public static let waitingFirstReport = "Away · waiting for the Pi's first report"
    public static let notSetUp = "Can't reach the Pi"
    public static let notSetUpDetail = "Set up Away in Settings to see the house from anywhere."
    public static let someEarlier = "Some readings are from earlier."
    public static let someMissing = "Some readings are missing."

    static func problem(_ problem: MailboxProblem) -> String {
        switch problem {
        case .offline:
            "Can't reach the mailbox right now."
        case .refused:
            "The mailbox refused the read token. Check Settings."
        case .wrongAddress:
            "Nothing answered at that mailbox address. Check Settings."
        case .notUnderstood:
            "This report can't be read. The app may need an update."
        }
    }
}
