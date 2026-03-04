//
//  WidgetAppStoreConnectClient.swift
//  Connect Reviews
//
//  Created by Diego Rivera on 4/3/26.
//

import Foundation
import CryptoKit

final class WidgetAppStoreConnectClient {
    private let session: URLSession
    private let credentials: WidgetAppStoreConnectCredentials
    private let useMockData: Bool

    init(session: URLSession = .shared, credentials: WidgetAppStoreConnectCredentials) {
        self.session = session
        self.credentials = credentials
        self.useMockData = WidgetAppleReviewDemoAccount.matches(credentials)
    }

    func fetchApps() async throws -> [WidgetAppResource] {
        if useMockData {
            let page: WidgetASCListResponse<WidgetAppResource> = try decodeMockASCFile(named: "apps")
            return page.data
        }
        let liveApps: [WidgetAppResource] = try await fetchAllPages(
            path: "apps?limit=200&fields[apps]=name,bundleId"
        )
        return liveApps
    }

    func fetchAppStoreVersions(appID: String) async throws -> [WidgetAppStoreVersionResource] {
        if useMockData {
            let page: WidgetASCListResponse<WidgetAppStoreVersionResource> = try decodeMockASCFile(
                named: "appStoreVersions_\(appID)"
            )
            return page.data
        }
        let versions: [WidgetAppStoreVersionResource] = try await fetchAllPages(
            path: "apps/\(appID)/appStoreVersions?limit=200&fields[appStoreVersions]=appStoreState"
        )
        return versions
    }

    func fetchITunesMetadataAcrossMainTerritories(
        appID: String,
        bundleID: String
    ) async -> WidgetITunesMetadataResult? {
        if useMockData {
            return mockITunesMetadata(appID: appID)
        }

        var iconURL: URL?
        var sellerName: String?
        var totalCount = 0
        var weightedSum = 0.0

        for territoryCode in ConnectReviewsWidgetConstants.iTunesMainTerritoryCodes {
            guard let metadata = await fetchITunesLookupMetadata(
                appID: appID,
                bundleID: bundleID,
                countryCode: territoryCode.lowercased()
            ) else {
                continue
            }

            if iconURL == nil {
                iconURL = metadata.iconURL
            }
            if sellerName == nil, let metadataSellerName = metadata.sellerName, !metadataSellerName.isEmpty {
                sellerName = metadataSellerName
            }

            guard
                let count = metadata.userRatingCount,
                count > 0,
                let average = metadata.averageUserRating,
                average > 0
            else {
                continue
            }

            totalCount += count
            weightedSum += Double(count) * average
        }

        if totalCount > 0 {
            return WidgetITunesMetadataResult(
                iconURL: iconURL,
                averageUserRating: weightedSum / Double(totalCount),
                userRatingCount: totalCount,
                sellerName: sellerName
            )
        }

        if let iconURL {
            return WidgetITunesMetadataResult(
                iconURL: iconURL,
                averageUserRating: nil,
                userRatingCount: nil,
                sellerName: sellerName
            )
        }

        return await fetchITunesLookupMetadata(appID: appID, bundleID: bundleID, countryCode: "us")
    }

    private func fetchAllPages<T: Decodable>(path: String) async throws -> [T] {
        var items: [T] = []
        guard let initialURL = URL(string: path, relativeTo: ConnectReviewsWidgetConstants.appStoreConnectBaseURL)?.absoluteURL else {
            throw WidgetDataError.decodingFailed
        }
        var nextURL = initialURL

        while true {
            let page: WidgetASCListResponse<T> = try await perform(url: nextURL)
            items.append(contentsOf: page.data)

            guard let next = page.links.next else {
                break
            }
            guard let nextResolved = URL(string: next, relativeTo: ConnectReviewsWidgetConstants.appStoreConnectBaseURL)?.absoluteURL else {
                break
            }
            nextURL = nextResolved
        }

        return items
    }

    private func perform<T: Decodable>(url: URL) async throws -> T {
        let data = try await performData(url: url)
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)
        } catch {
            throw WidgetDataError.decodingFailed
        }
    }

    private func performData(url: URL) async throws -> Data {
        let jwt = try WidgetJWTSigner.makeToken(credentials: credentials)
        var request = URLRequest(url: url)
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WidgetDataError.badResponse(statusCode: -1, body: "Non-HTTP response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "<non-utf8>"
            throw WidgetDataError.badResponse(statusCode: httpResponse.statusCode, body: body)
        }

        return data
    }

    private func fetchITunesLookupMetadata(
        appID: String,
        bundleID: String,
        countryCode: String
    ) async -> WidgetITunesMetadataResult? {
        let queryVariants: [[URLQueryItem]] = [
            [
                URLQueryItem(name: "id", value: appID),
                URLQueryItem(name: "country", value: countryCode)
            ],
            [
                URLQueryItem(name: "bundleId", value: bundleID),
                URLQueryItem(name: "country", value: countryCode)
            ]
        ]

        for queryItems in queryVariants {
            var components = URLComponents(url: ConnectReviewsWidgetConstants.iTunesLookupURL, resolvingAgainstBaseURL: false)
            components?.queryItems = queryItems + [URLQueryItem(name: "entity", value: ConnectReviewsWidgetConstants.iTunesLookupEntity)]
            guard let url = components?.url else { continue }

            do {
                var request = URLRequest(url: url)
                request.timeoutInterval = 20
                let (data, response) = try await session.data(for: request)
                guard
                    let http = response as? HTTPURLResponse,
                    (200...299).contains(http.statusCode)
                else {
                    continue
                }
                let decoded = try JSONDecoder().decode(WidgetITunesLookupResponse.self, from: data)
                guard let app = decoded.results.first else { continue }
                return WidgetITunesMetadataResult(
                    iconURL: app.artworkUrl100 ?? app.artworkUrl512,
                    averageUserRating: app.averageUserRating,
                    userRatingCount: app.userRatingCount,
                    sellerName: app.sellerName
                )
            } catch {
                continue
            }
        }

        return nil
    }

    private func mockITunesMetadata(appID: String) -> WidgetITunesMetadataResult? {
        guard let decoded = try? decodeMockITunesLookupFile(appID: appID) else { return nil }
        guard let app = decoded.results.first else { return nil }
        return WidgetITunesMetadataResult(
            iconURL: mockIconURL(appID: appID) ?? app.artworkUrl100 ?? app.artworkUrl512,
            averageUserRating: app.averageUserRating,
            userRatingCount: app.userRatingCount,
            sellerName: app.sellerName
        )
    }

    private func mockIconURL(appID: String) -> URL? {
        let fileName: String
        switch appID {
        case "6756281636":
            fileName = "better-1024"
        case "6473126292":
            fileName = "tildone-1024"
        case "6754349400":
            fileName = "week-1024"
        default:
            return nil
        }

        return findMockResourceURL(
            name: fileName,
            ext: "png",
            subdirectories: ["Mocks/Icons", "Icons", nil]
        )
    }

    private func decodeMockASCFile<T: Decodable>(named name: String) throws -> T {
        guard
            let url = findMockResourceURL(
                name: name,
                ext: "json",
                subdirectories: ["Mocks/ASC", "ASC", nil]
            )
        else {
            throw WidgetDataError.decodingFailed
        }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }

    private func decodeMockITunesLookupFile(appID: String) throws -> WidgetITunesLookupResponse {
        guard
            let url = findMockResourceURL(
                name: "lookup_\(appID)",
                ext: "json",
                subdirectories: ["Mocks/iTunes", "iTunes", nil]
            )
        else {
            throw WidgetDataError.decodingFailed
        }

        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(WidgetITunesLookupResponse.self, from: data)
    }

    private func findMockResourceURL(
        name: String,
        ext: String,
        subdirectories: [String?]
    ) -> URL? {
        for bundle in candidateBundles() {
            for subdirectory in subdirectories {
                if let url = bundle.url(forResource: name, withExtension: ext, subdirectory: subdirectory) {
                    return url
                }
            }
        }
        return nil
    }

    private func candidateBundles() -> [Bundle] {
        [Bundle.main, hostAppBundle()].compactMap { $0 }
    }

    private func hostAppBundle() -> Bundle? {
        let appBundleURL = Bundle.main.bundleURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return Bundle(url: appBundleURL)
    }
}

private struct WidgetASCLinks: Decodable {
    let next: String?
}

private struct WidgetASCListResponse<T: Decodable>: Decodable {
    let data: [T]
    let links: WidgetASCLinks
}

private struct WidgetITunesLookupResponse: Decodable {
    let results: [WidgetITunesAppResult]
}

struct WidgetITunesMetadataResult {
    let iconURL: URL?
    let averageUserRating: Double?
    let userRatingCount: Int?
    let sellerName: String?
}

struct WidgetITunesAppResult: Decodable {
    let artworkUrl100: URL?
    let artworkUrl512: URL?
    let averageUserRating: Double?
    let userRatingCount: Int?
    let sellerName: String?

    private enum CodingKeys: String, CodingKey {
        case artworkUrl100
        case artworkUrl512
        case averageUserRating
        case userRatingCount
        case sellerName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        artworkUrl100 = try container.decodeIfPresent(URL.self, forKey: .artworkUrl100)
        artworkUrl512 = try container.decodeIfPresent(URL.self, forKey: .artworkUrl512)
        averageUserRating = container.decodeLossyDouble(forKey: .averageUserRating)
        userRatingCount = container.decodeLossyInt(forKey: .userRatingCount)
        sellerName = try container.decodeIfPresent(String.self, forKey: .sellerName)
    }
}

private extension KeyedDecodingContainer {
    func decodeLossyInt(forKey key: Key) -> Int? {
        if let intValue = try? decodeIfPresent(Int.self, forKey: key) {
            return intValue
        }
        if let stringValue = try? decodeIfPresent(String.self, forKey: key),
            let parsed = Int(stringValue)
        {
            return parsed
        }
        if let doubleValue = try? decodeIfPresent(Double.self, forKey: key),
            !doubleValue.isNaN
        {
            return Int(doubleValue)
        }
        return nil
    }

    func decodeLossyDouble(forKey key: Key) -> Double? {
        if let doubleValue = try? decodeIfPresent(Double.self, forKey: key) {
            return doubleValue
        }
        if let intValue = try? decodeIfPresent(Int.self, forKey: key) {
            return Double(intValue)
        }
        if let stringValue = try? decodeIfPresent(String.self, forKey: key),
            let parsed = Double(stringValue)
        {
            return parsed
        }
        return nil
    }
}

enum WidgetDataError: LocalizedError {
    case credentialsFileMissing
    case invalidCredentials(String)
    case invalidPrivateKey
    case failedToSignJWT
    case invalidJWTEncoding
    case badResponse(statusCode: Int, body: String)
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .credentialsFileMissing:
            return "Open Connect Reviews and add App Store Connect credentials."
        case let .invalidCredentials(message):
            return message
        case .invalidPrivateKey:
            return "Unable to parse private key."
        case .failedToSignJWT:
            return "Failed to sign App Store Connect JWT."
        case .invalidJWTEncoding:
            return "Failed to encode JWT payload."
        case let .badResponse(statusCode, body):
            return "App Store Connect request failed (\(statusCode)): \(body)"
        case .decodingFailed:
            return "Failed to decode App Store Connect response."
        }
    }
}

private enum WidgetJWTSigner {
    static func makeToken(credentials: WidgetAppStoreConnectCredentials) throws -> String {
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
            throw WidgetDataError.invalidJWTEncoding
        }

        let privateKey: P256.Signing.PrivateKey
        do {
            privateKey = try P256.Signing.PrivateKey(pemRepresentation: credentials.privateKeyPEM)
        } catch {
            throw WidgetDataError.invalidPrivateKey
        }

        let signature: P256.Signing.ECDSASignature
        do {
            signature = try privateKey.signature(for: inputData)
        } catch {
            throw WidgetDataError.failedToSignJWT
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

