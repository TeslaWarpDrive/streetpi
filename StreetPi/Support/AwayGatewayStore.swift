import Foundation
import StreetPiCore

/// What Settings > Away shows for the gateway. The secret never comes back out of the Keychain.
struct AwayGatewayForm {
    var address = ""
    var saved = false
    var enabled = true
    var onSave: (String, String, String) -> AwayGatewaySaveResult = { _, _, _ in .failed }
    var onRemove: () -> AwayGatewaySaveResult = { .failed }
    var onEnabled: (Bool) -> Void = { _ in }
}

extension AwayKeyDraft {
    /// The rejected-key card saves through the same form the away section uses.
    mutating func save(with form: AwayGatewayForm) {
        save(address: form.address, onSave: form.onSave)
    }
}

extension AwayGatewaySettings {
    static func bundled() -> AwayGatewaySettings? {
        from(seed: ProvisionSeed.bundled()?.gateway)
    }

    static func from(seed: GatewaySeed?) -> AwayGatewaySettings? {
        seed.flatMap {
            AwayGatewaySettings(url: $0.url.absoluteString, clientID: $0.clientID, clientSecret: $0.clientSecret)
        }
    }
}

/// Gateway settings sit in one Keychain item. Only the on/off switch and the seed flag sit in settings.
/// `UserDefaults` is thread-safe and is not marked `Sendable` in this SDK.
struct AwayGatewayStore: @unchecked Sendable {
    private static let enabledKey = "settings.away.gatewayEnabled"
    private static let seedHandledKey = "settings.away.gatewaySeedHandled"

    private let store: any SecretStoring
    private let defaults: UserDefaults

    init(store: any SecretStoring, defaults: UserDefaults = .standard) {
        self.store = store
        self.defaults = defaults
    }

    /// On unless someone turned it off in Settings.
    var enabled: Bool {
        defaults.object(forKey: Self.enabledKey) == nil || defaults.bool(forKey: Self.enabledKey)
    }

    func setEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: Self.enabledKey)
    }

    func load() -> AwayGatewaySettings? {
        guard let data = try? store.load(for: AwayGatewaySettings.account) else { return nil }
        return AwayGatewaySettings(keychain: data)
    }

    /// The road to probe. Nil when none is saved or the switch is off.
    func active() -> AwayGatewaySettings? {
        enabled ? load() : nil
    }

    func addressText() -> String {
        load()?.origin ?? ""
    }

    /// Empty credential fields keep the saved ones, so the address can change on its own.
    func save(address: String, clientID: String, secret: String) -> AwayGatewaySaveResult {
        let current = load()
        let keepsCredentials = clientID.isEmpty && secret.isEmpty
        guard !keepsCredentials || current != nil else { return .missingCredentials }
        let id = keepsCredentials ? current?.clientID ?? "" : clientID
        let key = keepsCredentials ? current?.clientSecret ?? "" : secret
        guard AwayGatewaySettings(url: address, clientID: "fixed", clientSecret: "fixed") != nil else {
            return .badAddress
        }
        guard let settings = AwayGatewaySettings(url: address, clientID: id, clientSecret: key) else {
            return .missingCredentials
        }
        do {
            try store.save(try settings.keychainData(), for: AwayGatewaySettings.account)
        } catch {
            return .failed
        }
        defaults.set(true, forKey: Self.seedHandledKey)
        return .saved
    }

    func remove() -> AwayGatewaySaveResult {
        do {
            try store.delete(for: AwayGatewaySettings.account)
        } catch {
            return .failed
        }
        defaults.set(true, forKey: Self.seedHandledKey)
        return .saved
    }

    /// Fills an empty phone from the build, once. A failed save tries again next launch.
    func seedIfNeeded(from seed: AwayGatewaySettings?) {
        guard defaults.bool(forKey: Self.seedHandledKey) == false else { return }
        if load() != nil {
            defaults.set(true, forKey: Self.seedHandledKey)
            return
        }
        guard let seed else { return }
        _ = save(address: seed.origin, clientID: seed.clientID, secret: seed.clientSecret)
    }
}
