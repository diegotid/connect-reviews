import Foundation

@MainActor
final class AppStoreConnectClient {
    private let baseURL = URL(string: "https://api.appstoreconnect.apple.com/v1/")!
    private let session: URLSession
    private let credentials: AppStoreConnectCredentials

    init(
        session: URLSession = .shared,
        credentials: AppStoreConnectCredentials
    ) {
        self.session = session
        self.credentials = credentials
    }

    func fetchApps() async throws -> [AppResource] {
        try await fetchAllPages(path: "apps?limit=200&fields[apps]=name,bundleId")
    }

    func fetchReviews(appID: String) async throws -> [CustomerReviewResource] {
        try await fetchAllPages(path: "apps/\(appID)/customerReviews?limit=200&sort=-createdDate&fields[customerReviews]=rating,title,body,reviewerNickname,territory,createdDate")
    }

    func fetchIconURL(bundleID: String) async -> URL? {
        guard
            var components = URLComponents(string: "https://itunes.apple.com/lookup")
        else {
            return nil
        }
        components.queryItems = [
            URLQueryItem(name: "bundleId", value: bundleID),
            URLQueryItem(name: "country", value: "us")
        ]
        guard let url = components.url else { return nil }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 15
            let (data, response) = try await session.data(for: request)
            guard
                let http = response as? HTTPURLResponse,
                (200...299).contains(http.statusCode)
            else {
                return nil
            }

            let decoded = try JSONDecoder().decode(ITunesLookupResponse.self, from: data)
            return decoded.results.first?.artworkUrl100 ?? decoded.results.first?.artworkUrl512
        } catch {
            return nil
        }
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

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)
        } catch {
            throw AppStoreConnectError.decodingFailed
        }
    }
}

private struct ASCLinks: Decodable {
    let next: String?
}

private struct ASCListResponse<T: Decodable>: Decodable {
    let data: [T]
    let links: ASCLinks
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
    }
}

private struct ITunesLookupResponse: Decodable {
    let results: [ITunesAppResult]
}

private struct ITunesAppResult: Decodable {
    let artworkUrl100: URL?
    let artworkUrl512: URL?
}
