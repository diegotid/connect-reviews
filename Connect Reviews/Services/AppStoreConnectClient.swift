import Foundation

@MainActor
final class AppStoreConnectClient {
    private let baseURL = URL(string: "https://api.appstoreconnect.apple.com/v1/")!
    private let iTunesLookupURL = URL(string: "https://itunes.apple.com/lookup")!
    private let iTunesLookupEntity = "desktopSoftware"
    private let iTunesMainTerritoryCodes = [
        "US", "CA", "GB",
        "JP", "AU", "CN", "KR", "BR", "IN", "MX", "CH", "SG",
        "AT", "BE", "BG", "HR", "CY", "CZ", "DK", "EE", "FI", "FR", "DE", "GR",
        "HU", "IE", "IT", "LV", "LT", "LU", "MT", "NL", "PL", "PT", "RO", "SK",
        "SI", "ES", "SE"
    ]
    private let session: URLSession
    private let credentials: AppStoreConnectCredentials
    private let useMockData = true
#if DEBUG
    private let enableCustomerReviewsPayloadDebug = false
    private let customerReviewsDebugAppID: String? = nil
    private let customerReviewsDebugMaxChars = 10000
#else
    private let enableCustomerReviewsPayloadDebug = false
    private let customerReviewsDebugAppID: String? = nil
    private let customerReviewsDebugMaxChars = 0
#endif

    init(
        session: URLSession = .shared,
        credentials: AppStoreConnectCredentials
    ) {
        self.session = session
        self.credentials = credentials
    }

    func fetchApps() async throws -> [AppResource] {
        if useMockData {
            let page: ASCListResponse<AppResource> = try decodeMockASCFile(named: "apps")
            return page.data
        }
        return try await fetchAllPages(path: "apps?limit=200&fields[apps]=name,bundleId")
    }

    func fetchReviewsAndRatings(appID: String) async throws -> (reviews: [CustomerReviewResource], ratings: [TerritoryRating]) {
        if useMockData {
            let page: CustomerReviewsPage = try decodeMockASCFile(named: "customerReviews_\(appID)")
            var ratingsByTerritory: [String: TerritoryRating] = [:]

            for include in page.included ?? [] {
                guard let rating = include.attributes.userRating else { continue }
                guard let count = rating.ratingCount, count > 0 else { continue }
                guard let value = rating.value, value > 0 else { continue }

                let territoryCode =
                    (include.attributes.territory ?? include.attributes.territoryCode ?? "WW")
                    .uppercased()
                let incoming = TerritoryRating(
                    territoryCode: territoryCode,
                    reviewCount: count,
                    averageRating: value
                )

                if let existing = ratingsByTerritory[territoryCode] {
                    if incoming.reviewCount >= existing.reviewCount {
                        ratingsByTerritory[territoryCode] = incoming
                    }
                } else {
                    ratingsByTerritory[territoryCode] = incoming
                }
            }

            let ratings = ratingsByTerritory.values.sorted { $0.territoryCode < $1.territoryCode }
            return (reviews: page.data, ratings: ratings)
        }

        let path = "apps/\(appID)/customerReviews?limit=200&sort=-createdDate"
        guard let initialURL = URL(string: path, relativeTo: baseURL)?.absoluteURL else {
            throw AppStoreConnectError.decodingFailed
        }

        var nextURL = initialURL
        var allReviews: [CustomerReviewResource] = []
        var ratingsByTerritory: [String: TerritoryRating] = [:]
        var didDumpPayload = false

        while true {
            let pageData = try await performData(url: nextURL)
            if shouldDumpCustomerReviewsPayload(for: appID), !didDumpPayload {
                didDumpPayload = true
                debugPrintCustomerReviewsPayload(appID: appID, url: nextURL, data: pageData)
            }
            let page = try decodeCustomerReviewsPage(from: pageData)
            allReviews.append(contentsOf: page.data)

            for include in page.included ?? [] {
                guard let rating = include.attributes.userRating else { continue }
                guard let count = rating.ratingCount, count > 0 else { continue }
                guard let value = rating.value, value > 0 else { continue }

                let territoryCode =
                    (include.attributes.territory ?? include.attributes.territoryCode ?? "WW")
                    .uppercased()
                let incoming = TerritoryRating(
                    territoryCode: territoryCode,
                    reviewCount: count,
                    averageRating: value
                )

                if let existing = ratingsByTerritory[territoryCode] {
                    if incoming.reviewCount >= existing.reviewCount {
                        ratingsByTerritory[territoryCode] = incoming
                    }
                } else {
                    ratingsByTerritory[territoryCode] = incoming
                }
            }

            guard let next = page.links.next else { break }
            guard let resolved = URL(string: next, relativeTo: baseURL)?.absoluteURL else { break }
            nextURL = resolved
        }

        let ratings = ratingsByTerritory.values.sorted { $0.territoryCode < $1.territoryCode }
        return (reviews: allReviews, ratings: ratings)
    }

    func fetchAppStoreVersions(appID: String) async throws -> [AppStoreVersionResource] {
        if useMockData {
            let page: ASCListResponse<AppStoreVersionResource> = try decodeMockASCFile(
                named: "appStoreVersions_\(appID)"
            )
            return page.data
        }
        return try await fetchAllPages(path: "apps/\(appID)/appStoreVersions?limit=200&fields[appStoreVersions]=appStoreState")
    }

    func fetchITunesMetadata(
        appID: String,
        bundleID: String,
        countryCode: String = "us"
    ) async -> ITunesMetadataResult? {
        if useMockData {
            return mockITunesMetadata(appID: appID, bundleID: bundleID)
        }
        return await fetchITunesLookupMetadata(appID: appID, bundleID: bundleID, countryCode: countryCode)
    }

    func fetchVendorName(appID: String, bundleID: String) async -> String? {
        if useMockData {
            return mockITunesMetadata(appID: appID, bundleID: bundleID)?.sellerName
        }
        for territoryCode in iTunesMainTerritoryCodes {
            if let sellerName = await fetchITunesLookupMetadata(
                appID: appID,
                bundleID: bundleID,
                countryCode: territoryCode.lowercased()
            )?.sellerName,
                !sellerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            {
                return sellerName
            }
        }
        return nil
    }

    func fetchITunesMetadataAcrossMainTerritories(
        appID: String,
        bundleID: String
    ) async -> ITunesMetadataResult? {
        if useMockData {
            return mockITunesMetadata(appID: appID, bundleID: bundleID)
        }

        var iconURL: URL?
        var sellerName: String?
        var totalCount = 0
        var weightedSum = 0.0

        for territoryCode in iTunesMainTerritoryCodes {
            guard
                let metadata = await fetchITunesLookupMetadata(
                    appID: appID,
                    bundleID: bundleID,
                    countryCode: territoryCode.lowercased()
                )
            else {
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
            return ITunesMetadataResult(
                iconURL: iconURL,
                averageUserRating: weightedSum / Double(totalCount),
                userRatingCount: totalCount,
                sellerName: sellerName
            )
        }

        if let iconURL {
            return ITunesMetadataResult(
                iconURL: iconURL,
                averageUserRating: nil,
                userRatingCount: nil,
                sellerName: sellerName
            )
        }

        return await fetchITunesLookupMetadata(appID: appID, bundleID: bundleID, countryCode: "us")
    }

    func fetchIconURL(appID: String, bundleID: String) async -> URL? {
        let result = await fetchITunesMetadata(appID: appID, bundleID: bundleID)
        return result?.iconURL
    }

    private func fetchAllPages<T: Decodable>(path: String) async throws -> [T] {
        var items: [T] = []
        guard let initialURL = URL(string: path, relativeTo: baseURL)?.absoluteURL else {
            throw AppStoreConnectError.decodingFailed
        }
        var nextURL = initialURL

        while true {
            let page: ASCListResponse<T> = try await perform(url: nextURL)
            items.append(contentsOf: page.data)

            guard let next = page.links.next else {
                break
            }
            guard let nextResolved = URL(string: next, relativeTo: baseURL)?.absoluteURL else {
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
            throw AppStoreConnectError.decodingFailed
        }
    }

    private func performData(url: URL) async throws -> Data {
        let jwt = try JWTSigner.makeToken(credentials: credentials)
        var request = URLRequest(url: url)
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppStoreConnectError.badResponse(statusCode: -1, body: "Non-HTTP response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "<non-utf8>"
            throw AppStoreConnectError.badResponse(statusCode: httpResponse.statusCode, body: body)
        }

        return data
    }

    private func decodeCustomerReviewsPage(from data: Data) throws -> CustomerReviewsPage {
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(CustomerReviewsPage.self, from: data)
        } catch {
            throw AppStoreConnectError.decodingFailed
        }
    }

    private func shouldDumpCustomerReviewsPayload(for appID: String) -> Bool {
        guard enableCustomerReviewsPayloadDebug else { return false }
        guard let customerReviewsDebugAppID else { return true }
        return customerReviewsDebugAppID == appID
    }

    private func debugPrintCustomerReviewsPayload(appID: String, url: URL, data: Data) {
        let rawBody = String(data: data, encoding: .utf8) ?? "<non-utf8>"
        let snippet = String(rawBody.prefix(customerReviewsDebugMaxChars))
        print("[ASC CustomerReviews Debug] appID=\(appID) url=\(url.absoluteString)")
        print("[ASC CustomerReviews Debug] body:\n\(snippet)")
        if rawBody.count > snippet.count {
            print("[ASC CustomerReviews Debug] body truncated at \(snippet.count) chars")
        }
    }

    private func fetchITunesLookupMetadata(
        appID: String,
        bundleID: String,
        countryCode: String
    ) async -> ITunesMetadataResult? {
        let queryVariants: [(name: String, items: [URLQueryItem])] = [
            (
                "id",
                [
                    URLQueryItem(name: "id", value: appID),
                    URLQueryItem(name: "country", value: countryCode)
                ]
            ),
            (
                "bundleId",
                [
                    URLQueryItem(name: "bundleId", value: bundleID),
                    URLQueryItem(name: "country", value: countryCode)
                ]
            )
        ]

        for query in queryVariants {
            var components = URLComponents(url: iTunesLookupURL, resolvingAgainstBaseURL: false)
            components?.queryItems = query.items + [
                URLQueryItem(name: "entity", value: iTunesLookupEntity)
            ]
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
                let decoded = try JSONDecoder().decode(ITunesLookupResponse.self, from: data)
                guard let app = decoded.results.first else { continue }
                return ITunesMetadataResult(
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

    private func mockITunesMetadata(appID: String, bundleID: String) -> ITunesMetadataResult? {
        guard let decoded = try? decodeMockITunesLookupFile(appID: appID) else { return nil }
        guard let app = decoded.results.first else { return nil }
        return ITunesMetadataResult(
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

        return
            Bundle.main.url(
                forResource: fileName,
                withExtension: "png",
                subdirectory: "Mocks/Icons"
            ) ??
            Bundle.main.url(
                forResource: fileName,
                withExtension: "png",
                subdirectory: "Icons"
            ) ??
            Bundle.main.url(
                forResource: fileName,
                withExtension: "png"
            )
    }

    private func decodeMockASCFile<T: Decodable>(named name: String) throws -> T {
        let url =
            Bundle.main.url(
                forResource: name,
                withExtension: "json",
                subdirectory: "Mocks/ASC"
            ) ??
            Bundle.main.url(
                forResource: name,
                withExtension: "json",
                subdirectory: "ASC"
            ) ??
            Bundle.main.url(
                forResource: name,
                withExtension: "json"
            )

        guard let url else {
            throw AppStoreConnectError.decodingFailed
        }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }

    private func decodeMockITunesLookupFile(appID: String) throws -> ITunesLookupResponse {
        let url =
            Bundle.main.url(
                forResource: "lookup_\(appID)",
                withExtension: "json",
                subdirectory: "Mocks/iTunes"
            ) ??
            Bundle.main.url(
                forResource: "lookup_\(appID)",
                withExtension: "json",
                subdirectory: "iTunes"
            ) ??
            Bundle.main.url(
                forResource: "lookup_\(appID)",
                withExtension: "json"
            )

        guard let url else {
            throw AppStoreConnectError.decodingFailed
        }

        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(ITunesLookupResponse.self, from: data)
    }

}

private struct ASCLinks: Decodable {
    let next: String?
}

private struct ASCListResponse<T: Decodable>: Decodable {
    let data: [T]
    let links: ASCLinks
}

private struct CustomerReviewsPage: Decodable {
    let data: [CustomerReviewResource]
    let included: [CustomerReviewsIncludedResource]?
    let links: ASCLinks
}

private struct CustomerReviewsIncludedResource: Decodable {
    let attributes: Attributes

    struct Attributes: Decodable {
        let territory: String?
        let territoryCode: String?
        let userRating: UserRating?

        struct UserRating: Decodable {
            let ratingCount: Int?
            let value: Double?

            private enum CodingKeys: String, CodingKey {
                case ratingCount
                case value
            }

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                ratingCount = container.decodeLossyInt(forKey: .ratingCount)
                value = container.decodeLossyDouble(forKey: .value)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case territory
            case territoryCode
            case userRating
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            territory =
                try container.decodeIfPresent(String.self, forKey: .territory) ??
                container.decodeLossyString(forKey: .territoryCode)
            territoryCode = container.decodeLossyString(forKey: .territoryCode)
            userRating = try container.decodeIfPresent(UserRating.self, forKey: .userRating)
        }
    }
}

struct AppResource: Decodable {
    let id: String
    let attributes: Attributes

    struct Attributes: Decodable {
        let name: String
        let bundleId: String
    }
}

struct CustomerReviewResource: Decodable {
    let id: String
    let attributes: Attributes

    struct Attributes: Decodable {
        let rating: Int?
        let title: String?
        let body: String?
        let reviewerNickname: String?
        let territory: String?
        let createdDate: Date?

        private enum CodingKeys: String, CodingKey {
            case rating
            case title
            case body
            case reviewerNickname
            case territory
            case territoryCode
            case createdDate
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            rating = container.decodeLossyInt(forKey: .rating)
            title = try container.decodeIfPresent(String.self, forKey: .title)
            body = try container.decodeIfPresent(String.self, forKey: .body)
            reviewerNickname = try container.decodeIfPresent(String.self, forKey: .reviewerNickname)
            territory =
                try container.decodeIfPresent(String.self, forKey: .territory) ??
                container.decodeLossyString(forKey: .territoryCode)
            createdDate = try container.decodeIfPresent(Date.self, forKey: .createdDate)
        }
    }
}

struct AppStoreVersionResource: Decodable {
    let id: String
    let attributes: Attributes

    struct Attributes: Decodable {
        let appStoreState: String?
    }
}

private struct ITunesLookupResponse: Decodable {
    let results: [ITunesAppResult]
}

private struct ITunesAppResult: Decodable {
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

struct ITunesMetadataResult {
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
        if let stringValue = try? decodeIfPresent(String.self, forKey: key) {
            return Int(stringValue)
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
        if let stringValue = try? decodeIfPresent(String.self, forKey: key) {
            return Double(stringValue)
        }
        return nil
    }

    func decodeLossyString(forKey key: Key) -> String? {
        if let stringValue = try? decodeIfPresent(String.self, forKey: key) {
            return stringValue
        }
        if let intValue = try? decodeIfPresent(Int.self, forKey: key) {
            return String(intValue)
        }
        if let doubleValue = try? decodeIfPresent(Double.self, forKey: key) {
            return String(doubleValue)
        }
        return nil
    }
}
