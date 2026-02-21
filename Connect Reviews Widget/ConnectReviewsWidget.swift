import WidgetKit
import SwiftUI
import Foundation
import CryptoKit
import AppKit

private enum SidebarWidgetConstants {
    static let kind = "ConnectReviewsSidebarWidget"
    static let refreshInterval: TimeInterval = 6 * 60 * 60
    static let appStoreConnectBaseURL = URL(string: "https://api.appstoreconnect.apple.com/v1/")!
    static let iTunesLookupURL = URL(string: "https://itunes.apple.com/lookup")!
    static let iTunesLookupEntity = "desktopSoftware"
    static let iTunesMainTerritoryCodes = [
        "US", "CA", "GB",
        "JP", "AU", "CN", "KR", "BR", "IN", "MX", "CH", "SG",
        "AT", "BE", "BG", "HR", "CY", "CZ", "DK", "EE", "FI", "FR", "DE", "GR",
        "HU", "IE", "IT", "LV", "LT", "LU", "MT", "NL", "PL", "PT", "RO", "SK",
        "SI", "ES", "SE"
    ]
}

struct ConnectReviewsSidebarWidgetEntry: TimelineEntry {
    let date: Date
    let vendorName: String
    let apps: [ConnectReviewsSidebarApp]
    let errorMessage: String?
}

struct ConnectReviewsSidebarApp: Identifiable, Hashable {
    let id: String
    let name: String
    let bundleID: String
    let iconURL: URL?
    let iconData: Data?
    let averageRating: Double?
    let totalRatingsCount: Int?
}

private struct ConnectReviewsSidebarProvider: TimelineProvider {
    private let dataLoader = ConnectReviewsWidgetDataLoader()

    func placeholder(in context: Context) -> ConnectReviewsSidebarWidgetEntry {
        ConnectReviewsSidebarWidgetEntry(
            date: Date(),
            vendorName: "Apps",
            apps: [
                ConnectReviewsSidebarApp(
                    id: "placeholder",
                    name: "Sample App",
                    bundleID: "studio.cuatro.sample",
                    iconURL: nil,
                    iconData: nil,
                    averageRating: 4.2,
                    totalRatingsCount: 128
                )
            ],
            errorMessage: nil
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (ConnectReviewsSidebarWidgetEntry) -> Void) {
        Task {
            completion(await dataLoader.load())
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ConnectReviewsSidebarWidgetEntry>) -> Void) {
        Task {
            let entry = await dataLoader.load()
            let nextRefresh = Date().addingTimeInterval(SidebarWidgetConstants.refreshInterval)
            completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
        }
    }
}

private struct ConnectReviewsSidebarWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ConnectReviewsSidebarWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if entry.apps.isEmpty {
                Text(entry.errorMessage ?? "Open Connect Reviews to load apps.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(entry.apps.prefix(3)) { app in
                        VStack(alignment: .leading, spacing: 1) {
                            Text(app.name)
                                .lineLimit(1)
                                .padding(.bottom, 2)
                            if let averageRating = app.averageRating {
                                WidgetStarRating(
                                    rating: averageRating,
                                    ratingCount: app.totalRatingsCount,
                                    size: 9
                                )
                            } else {
                                Text("No rating")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(2)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

private struct WidgetStarRating: View {
    let rating: Double
    let ratingCount: Int?
    let size: CGFloat

    private var clampedRating: Double {
        min(max(rating, 0), 5)
    }

    private func starValue(at index: Int) -> Double {
        min(max(clampedRating - Double(index), 0), 1)
    }

    var body: some View {
        HStack(spacing: 2) {
            Text(String(format: "%.1f", rating))
                .bold()
                .foregroundStyle(.secondary)
                .font(.system(size: size * 1.3))
                .padding(.trailing, size / 4)
            ForEach(0..<5, id: \.self) { index in
                let value = starValue(at: index)
                ZStack {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.gray.opacity(0.2))
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow.opacity(value * 0.5))
                }
            }
            if let ratingCount {
                Text("(\(ratingCount))")
                    .font(.system(size: size * 1.25, weight: .light))
                    .foregroundStyle(.secondary)
            }
        }
        .font(.system(size: size, weight: .semibold))
    }
}

private struct WidgetAppIcon: View {
    let iconData: Data?
    let size: CGFloat

    var body: some View {
        Group {
            if let iconData, let image = NSImage(data: iconData) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                iconPlaceholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
        .overlay {
            RoundedRectangle(cornerRadius: size * 0.22)
                .strokeBorder(.black.opacity(0.08))
        }
    }

    private var iconPlaceholder: some View {
        RoundedRectangle(cornerRadius: size * 0.22)
            .fill(.quinary)
            .overlay {
                Image(systemName: "app")
                    .foregroundStyle(.secondary)
            }
    }
}

struct ConnectReviewsSidebarWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: SidebarWidgetConstants.kind,
            provider: ConnectReviewsSidebarProvider()
        ) { entry in
            ConnectReviewsSidebarWidgetView(entry: entry)
        }
        .configurationDisplayName("Connect Reviews")
        .description("Shows Ready for Sale apps and their average ratings.")
        .supportedFamilies([.systemSmall])
    }
}

@main
struct ConnectReviewsWidgetBundle: WidgetBundle {
    var body: some Widget {
        ConnectReviewsSidebarWidget()
    }
}

private actor ConnectReviewsWidgetDataLoader {
    func load() async -> ConnectReviewsSidebarWidgetEntry {
        do {
            let client = try WidgetAppStoreConnectClient()
            let appResources = try await client.fetchApps()

            let loaded = try await withThrowingTaskGroup(of: LoadedWidgetApp?.self) { group in
                for resource in appResources {
                    group.addTask {
                        let versions = (try? await client.fetchAppStoreVersions(appID: resource.id)) ?? []
                        let states = versions.compactMap(\.attributes.appStoreState).filter { !$0.isEmpty }
                        guard states.contains("READY_FOR_SALE") else {
                            return nil
                        }

                        let metadata = await client.fetchITunesMetadataAcrossMainTerritories(
                            appID: resource.id,
                            bundleID: resource.attributes.bundleId
                        )
                        let iconData = await self.fetchIconData(url: metadata?.iconURL)

                        return LoadedWidgetApp(
                            app: ConnectReviewsSidebarApp(
                                id: resource.id,
                                name: resource.attributes.name,
                                bundleID: resource.attributes.bundleId,
                                iconURL: metadata?.iconURL,
                                iconData: iconData,
                                averageRating: metadata?.averageUserRating,
                                totalRatingsCount: metadata?.userRatingCount
                            ),
                            sellerName: metadata?.sellerName
                        )
                    }
                }

                var values: [LoadedWidgetApp] = []
                for try await candidate in group {
                    if let candidate {
                        values.append(candidate)
                    }
                }
                return values
            }

            let sortedApps = loaded.map(\.app).sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }

            let vendorNameFromMetadata = loaded
                .compactMap(\.sellerName)
                .first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

            let vendorName = vendorNameFromMetadata ?? "Apps"

            return ConnectReviewsSidebarWidgetEntry(
                date: Date(),
                vendorName: vendorName,
                apps: sortedApps,
                errorMessage: nil
            )
        } catch {
            return ConnectReviewsSidebarWidgetEntry(
                date: Date(),
                vendorName: "Apps",
                apps: [],
                errorMessage: error.localizedDescription
            )
        }
    }

    private func fetchIconData(url: URL?) async -> Data? {
        guard let url else { return nil }

        do {
            if url.isFileURL {
                return try Data(contentsOf: url)
            }

            let (data, response) = try await URLSession.shared.data(from: url)
            guard
                let http = response as? HTTPURLResponse,
                (200...299).contains(http.statusCode)
            else {
                return nil
            }
            return data
        } catch {
            return nil
        }
    }
}

private struct LoadedWidgetApp {
    let app: ConnectReviewsSidebarApp
    let sellerName: String?
}

private struct WidgetAppStoreConnectCredentials {
    let issuerID: String
    let keyID: String
    let privateKeyPEM: String
}

private enum WidgetCredentialsLoader {
    static func load() throws -> WidgetAppStoreConnectCredentials {
        let candidateBundles = [Bundle.main, hostAppBundle()].compactMap { $0 }

        for bundle in candidateBundles {
            guard let url = credentialsURL(in: bundle) else { continue }
            return try parseCredentials(at: url)
        }

        throw WidgetDataError.credentialsFileMissing
    }

    private static func credentialsURL(in bundle: Bundle) -> URL? {
        bundle.url(
            forResource: "AppStoreConnectCredentials",
            withExtension: "plist",
            subdirectory: "Secrets"
        ) ?? bundle.url(
            forResource: "AppStoreConnectCredentials",
            withExtension: "plist"
        )
    }

    private static func hostAppBundle() -> Bundle? {
        let appBundleURL = Bundle.main.bundleURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return Bundle(url: appBundleURL)
    }

    private static func parseCredentials(at url: URL) throws -> WidgetAppStoreConnectCredentials {
        let data = try Data(contentsOf: url)
        let raw = try PropertyListSerialization.propertyList(from: data, format: nil)

        guard let dict = raw as? [String: Any] else {
            throw WidgetDataError.invalidCredentials("Credentials plist format is invalid.")
        }

        guard let issuerID = dict["issuerID"] as? String, !issuerID.isEmpty else {
            throw WidgetDataError.invalidCredentials("Missing `issuerID` in credentials plist.")
        }
        guard let keyID = dict["keyID"] as? String, !keyID.isEmpty else {
            throw WidgetDataError.invalidCredentials("Missing `keyID` in credentials plist.")
        }
        guard let privateKey = dict["privateKey"] as? String, !privateKey.isEmpty else {
            throw WidgetDataError.invalidCredentials("Missing `privateKey` in credentials plist.")
        }

        return WidgetAppStoreConnectCredentials(
            issuerID: issuerID,
            keyID: keyID,
            privateKeyPEM: privateKey
        )
    }
}

private enum WidgetDataError: LocalizedError {
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
            return "Missing AppStoreConnectCredentials.plist."
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

private final class WidgetAppStoreConnectClient {
    private static let useMockData = true
    private let session: URLSession
    private let credentials: WidgetAppStoreConnectCredentials?

    init(session: URLSession = .shared) throws {
        self.session = session
        if Self.useMockData {
            self.credentials = nil
        } else {
            self.credentials = try WidgetCredentialsLoader.load()
        }
    }

    func fetchApps() async throws -> [WidgetAppResource] {
        if Self.useMockData {
            let page: WidgetASCListResponse<WidgetAppResource> = try decodeMockASCFile(named: "apps")
            return page.data
        }

        return try await fetchAllPages(path: "apps?limit=200&fields[apps]=name,bundleId")
    }

    func fetchAppStoreVersions(appID: String) async throws -> [WidgetAppStoreVersionResource] {
        if Self.useMockData {
            let page: WidgetASCListResponse<WidgetAppStoreVersionResource> = try decodeMockASCFile(
                named: "appStoreVersions_\(appID)"
            )
            return page.data
        }

        return try await fetchAllPages(path: "apps/\(appID)/appStoreVersions?limit=200&fields[appStoreVersions]=appStoreState")
    }

    func fetchITunesMetadataAcrossMainTerritories(
        appID: String,
        bundleID: String
    ) async -> WidgetITunesMetadataResult? {
        if Self.useMockData {
            return mockITunesMetadata(appID: appID)
        }

        var iconURL: URL?
        var sellerName: String?
        var totalCount = 0
        var weightedSum = 0.0

        for territoryCode in SidebarWidgetConstants.iTunesMainTerritoryCodes {
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
        guard let initialURL = URL(string: path, relativeTo: SidebarWidgetConstants.appStoreConnectBaseURL)?.absoluteURL else {
            throw WidgetDataError.decodingFailed
        }
        var nextURL = initialURL

        while true {
            let page: WidgetASCListResponse<T> = try await perform(url: nextURL)
            items.append(contentsOf: page.data)

            guard let next = page.links.next else {
                break
            }
            guard let nextResolved = URL(string: next, relativeTo: SidebarWidgetConstants.appStoreConnectBaseURL)?.absoluteURL else {
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
        guard let credentials else {
            throw WidgetDataError.invalidCredentials("Missing credentials for non-mock mode.")
        }
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
            var components = URLComponents(url: SidebarWidgetConstants.iTunesLookupURL, resolvingAgainstBaseURL: false)
            components?.queryItems = queryItems + [URLQueryItem(name: "entity", value: SidebarWidgetConstants.iTunesLookupEntity)]
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

private struct WidgetAppResource: Decodable {
    let id: String
    let attributes: Attributes

    struct Attributes: Decodable {
        let name: String
        let bundleId: String
    }
}

private struct WidgetAppStoreVersionResource: Decodable {
    let attributes: Attributes

    struct Attributes: Decodable {
        let appStoreState: String?
    }
}

private struct WidgetITunesLookupResponse: Decodable {
    let results: [WidgetITunesAppResult]
}

private struct WidgetITunesAppResult: Decodable {
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

private struct WidgetITunesMetadataResult {
    let iconURL: URL?
    let averageUserRating: Double?
    let userRatingCount: Int?
    let sellerName: String?
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
