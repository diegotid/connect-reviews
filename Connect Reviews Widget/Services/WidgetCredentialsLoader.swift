//
//  WidgetCredentialsLoader.swift
//  Connect Reviews
//
//  Created by Diego Rivera on 4/3/26.
//

import Foundation

enum WidgetCredentialsLoader {
    static func load() throws -> WidgetAppStoreConnectCredentials {
        guard let defaults = UserDefaults(suiteName: ConnectReviewsWidgetConstants.appGroupIdentifier) else {
            throw WidgetDataError.invalidCredentials("Unable to access shared app group credentials.")
        }
        guard let data = defaults.data(forKey: ConnectReviewsWidgetConstants.credentialsStorageKey) else {
            throw WidgetDataError.credentialsFileMissing
        }

        let decoded: StoredCredentials
        do {
            decoded = try JSONDecoder().decode(StoredCredentials.self, from: data)
        } catch {
            throw WidgetDataError.invalidCredentials("Saved shared credentials are invalid.")
        }

        let issuerID = decoded.issuerID.trimmingCharacters(in: .whitespacesAndNewlines)
        let keyID = decoded.keyID.trimmingCharacters(in: .whitespacesAndNewlines)
        let privateKey = decoded.privateKeyPEM.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !issuerID.isEmpty else {
            throw WidgetDataError.invalidCredentials("Missing Issuer ID.")
        }
        guard !keyID.isEmpty else {
            throw WidgetDataError.invalidCredentials("Missing Key ID.")
        }
        guard !privateKey.isEmpty else {
            throw WidgetDataError.invalidCredentials("Missing private key.")
        }

        return WidgetAppStoreConnectCredentials(
            issuerID: issuerID,
            keyID: keyID,
            privateKeyPEM: privateKey
        )
    }

    private struct StoredCredentials: Codable {
        let issuerID: String
        let keyID: String
        let privateKeyPEM: String
    }
}
