import Foundation
import CryptoKit

enum JWTSigner {
    static func makeToken(credentials: AppStoreConnectCredentials) throws -> String {
        let header: [String: Any] = [
            "alg": "ES256",
            "kid": credentials.keyID,
            "typ": "JWT"
        ]

        let now = Date()
        let expiry = now.addingTimeInterval(20 * 60)
        let payload: [String: Any] = [
            "iss": credentials.issuerID,
            "iat": Int(now.timeIntervalSince1970),
            "exp": Int(expiry.timeIntervalSince1970),
            "aud": "appstoreconnect-v1"
        ]

        let headerData = try JSONSerialization.data(withJSONObject: header)
        let payloadData = try JSONSerialization.data(withJSONObject: payload)

        let headerPart = base64URLEncode(headerData)
        let payloadPart = base64URLEncode(payloadData)
        let signingInput = "\(headerPart).\(payloadPart)"

        guard let inputData = signingInput.data(using: .utf8) else {
            throw AppStoreConnectError.invalidJWTEncoding
        }

        let privateKey: P256.Signing.PrivateKey
        do {
            privateKey = try P256.Signing.PrivateKey(pemRepresentation: credentials.privateKeyPEM)
        } catch {
            throw AppStoreConnectError.invalidPrivateKey
        }

        let signature: P256.Signing.ECDSASignature
        do {
            signature = try privateKey.signature(for: inputData)
        } catch {
            throw AppStoreConnectError.failedToSignJWT
        }

        return "\(signingInput).\(base64URLEncode(signature.rawRepresentation))"
    }

    private static func base64URLEncode(_ data: Data) -> String {
        data
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
