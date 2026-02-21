import Foundation
import Combine
#if canImport(WidgetKit)
import WidgetKit
#endif

enum SharedCredentialsConfig {
    static let appGroupIdentifier = "group.studio.cuatro.connect"
    static let storageKey = "app_store_connect_credentials_v1"
}

struct AppStoreConnectCredentials: Codable, Equatable {
    let issuerID: String
    let keyID: String
    let privateKeyPEM: String
}

@MainActor
final class CredentialsStore: ObservableObject {
    @Published private(set) var credentials: AppStoreConnectCredentials?
    @Published var isPresentingEditor = false

    var hasCredentials: Bool { credentials != nil }

    private let defaults: UserDefaults
    private let legacyDefaults: UserDefaults
    private let usesAppGroupDefaults: Bool

    init() {
        let appGroupDefaults = UserDefaults(suiteName: SharedCredentialsConfig.appGroupIdentifier)
        self.defaults = appGroupDefaults ?? .standard
        self.legacyDefaults = .standard
        self.usesAppGroupDefaults = appGroupDefaults != nil

        if let existing = Self.load(from: self.defaults) {
            self.credentials = existing
            return
        }

        if usesAppGroupDefaults, let legacy = Self.load(from: legacyDefaults) {
            self.credentials = legacy
            if let encoded = try? JSONEncoder().encode(legacy) {
                self.defaults.set(encoded, forKey: SharedCredentialsConfig.storageKey)
            }
            legacyDefaults.removeObject(forKey: SharedCredentialsConfig.storageKey)
        } else {
            self.credentials = nil
        }
    }

    func beginEditingCredentials() {
        isPresentingEditor = true
    }

    func save(
        issuerID: String,
        keyID: String,
        privateKeyPEM: String
    ) throws {
        let cleanIssuerID = issuerID.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanKeyID = keyID.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPrivateKey = privateKeyPEM
            .replacingOccurrences(of: "\\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanIssuerID.isEmpty else {
            throw AppStoreConnectError.invalidCredentials("Issuer ID is required.")
        }
        guard !cleanKeyID.isEmpty else {
            throw AppStoreConnectError.invalidCredentials("Key ID is required.")
        }
        guard !cleanPrivateKey.isEmpty else {
            throw AppStoreConnectError.invalidCredentials("Private key is required.")
        }

        let credentials = AppStoreConnectCredentials(
            issuerID: cleanIssuerID,
            keyID: cleanKeyID,
            privateKeyPEM: cleanPrivateKey
        )

        let encoded = try JSONEncoder().encode(credentials)
        defaults.set(encoded, forKey: SharedCredentialsConfig.storageKey)
        if usesAppGroupDefaults {
            legacyDefaults.removeObject(forKey: SharedCredentialsConfig.storageKey)
        }

        self.credentials = credentials
        isPresentingEditor = false
        reloadWidgetTimelines()
    }

    func clearCredentials() {
        defaults.removeObject(forKey: SharedCredentialsConfig.storageKey)
        legacyDefaults.removeObject(forKey: SharedCredentialsConfig.storageKey)
        credentials = nil
        isPresentingEditor = false
        reloadWidgetTimelines()
    }

    private static func load(from defaults: UserDefaults) -> AppStoreConnectCredentials? {
        guard let data = defaults.data(forKey: SharedCredentialsConfig.storageKey) else { return nil }
        return try? JSONDecoder().decode(AppStoreConnectCredentials.self, from: data)
    }

    private func reloadWidgetTimelines() {
#if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
#endif
    }
}
