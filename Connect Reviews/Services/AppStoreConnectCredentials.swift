import Foundation
import Combine

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
    private static let storageKey = "app_store_connect_credentials_v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.credentials = Self.load(from: defaults)
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
        defaults.set(encoded, forKey: Self.storageKey)

        self.credentials = credentials
        isPresentingEditor = false
    }

    func clearCredentials() {
        defaults.removeObject(forKey: Self.storageKey)
        credentials = nil
        isPresentingEditor = false
    }

    private static func load(from defaults: UserDefaults) -> AppStoreConnectCredentials? {
        guard let data = defaults.data(forKey: Self.storageKey) else { return nil }
        return try? JSONDecoder().decode(AppStoreConnectCredentials.self, from: data)
    }
}
