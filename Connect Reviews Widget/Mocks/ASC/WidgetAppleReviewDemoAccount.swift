//
//  WidgetAppleReviewDemoAccount.swift
//  Connect Reviews
//
//  Created by Diego Rivera on 4/3/26.
//

enum WidgetAppleReviewDemoAccount {
    static let issuerID = "00000000-0000-0000-0000-000000000000"
    static let keyID = "RVWDEMO001"
    static let privateKeyPEM = """
    -----BEGIN PRIVATE KEY-----
    APPLE_REVIEW_DEMO_PRIVATE_KEY
    -----END PRIVATE KEY-----
    """

    static func matches(_ credentials: WidgetAppStoreConnectCredentials) -> Bool {
        credentials.issuerID.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(issuerID) == .orderedSame &&
        credentials.keyID.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(keyID) == .orderedSame &&
        credentials.privateKeyPEM
            .replacingOccurrences(of: "\\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines) == privateKeyPEM
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
