import Foundation

struct AppStoreConnectCredentials {
    let issuerID: String
    let keyID: String
    let privateKeyPEM: String
}

enum CredentialsLoader {
    static func load() throws -> AppStoreConnectCredentials {
        let url =
            Bundle.main.url(
                forResource: "AppStoreConnectCredentials",
                withExtension: "plist",
                subdirectory: "Secrets"
            ) ??
            Bundle.main.url(
                forResource: "AppStoreConnectCredentials",
                withExtension: "plist"
            )

        guard let url else {
            throw AppStoreConnectError.credentialsFileMissing
        }

        let data = try Data(contentsOf: url)
        let raw = try PropertyListSerialization.propertyList(from: data, format: nil)

        guard let dict = raw as? [String: Any] else {
            throw AppStoreConnectError.invalidCredentials("Credentials plist format is invalid.")
        }

        guard let issuerID = dict["issuerID"] as? String, !issuerID.isEmpty else {
            throw AppStoreConnectError.invalidCredentials("Missing `issuerID` in credentials plist.")
        }
        guard let keyID = dict["keyID"] as? String, !keyID.isEmpty else {
            throw AppStoreConnectError.invalidCredentials("Missing `keyID` in credentials plist.")
        }
        guard let privateKey = dict["privateKey"] as? String, !privateKey.isEmpty else {
            throw AppStoreConnectError.invalidCredentials("Missing `privateKey` in credentials plist.")
        }

        return AppStoreConnectCredentials(
            issuerID: issuerID,
            keyID: keyID,
            privateKeyPEM: privateKey
        )
    }
}
