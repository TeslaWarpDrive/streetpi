import LocalAuthentication
import StreetPiCore

enum FaceIDGate {
    /// Face ID, or the device passcode when Face ID is unavailable. Protects the action.
    static func prompt(reason: String) async -> FaceIDPrompt {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return .failed
        }
        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, evalError in
                continuation.resume(returning: Self.answer(success: success, error: evalError))
            }
        }
    }

    /// A pass is the only result that may send. Deny can be tried again. Cancel and failure cannot send.
    private static func answer(success: Bool, error: Error?) -> FaceIDPrompt {
        if success { return .passed }
        let code = (error as? LAError)?.code
        if code == .userCancel || code == .appCancel || code == .systemCancel {
            return .cancelled
        }
        if code == .authenticationFailed { return .denied }
        return .failed
    }
}
