import Foundation

struct ConnectApp: Identifiable, Hashable {
    let id: String
    let name: String
    let bundleID: String
    let appStoreStates: [String]
    let primaryAppStoreState: String?
    let iconURL: URL?
    let ratingsByTerritory: [TerritoryRating]
    let hasAllRatingsCoverage: Bool
    let totalRatingsCount: Int
    let ratingsFromReviewsCount: Int
    let ratingsWithoutReviewCount: Int?
    let textReviewCount: Int
    let averageRating: Double?
    let reviews: [AppReview]
}

struct TerritoryRating: Identifiable, Hashable {
    var id: String { territoryCode }
    let territoryCode: String
    let reviewCount: Int
    let averageRating: Double
}

struct AppReview: Identifiable, Hashable {
    let id: String
    let rating: Int
    let territoryCode: String
    let title: String?
    let body: String?
    let reviewerNickname: String?
    let createdDate: Date?
}

enum AppStoreConnectError: LocalizedError {
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
            return "Missing App Store Connect credentials."
        case let .invalidCredentials(message):
            return message
        case .invalidPrivateKey:
            return "Unable to parse the private key from credentials."
        case .failedToSignJWT:
            return "Failed to sign JWT for App Store Connect."
        case .invalidJWTEncoding:
            return "Failed to encode JWT payload."
        case let .badResponse(statusCode, body):
            return "App Store Connect request failed (\(statusCode)): \(body)"
        case .decodingFailed:
            return "Failed to decode App Store Connect response."
        }
    }
}
