import Foundation
import Combine

@MainActor
final class ConnectStore: ObservableObject {
    @Published private(set) var apps: [ConnectApp] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    func refresh() async {
        isLoading = true
        errorMessage = nil

        do {
            let credentials = try CredentialsLoader.load()
            let client = AppStoreConnectClient(credentials: credentials)
            let appResources = try await client.fetchApps()

            let loadedApps = try await withThrowingTaskGroup(of: ConnectApp.self) { group in
                for app in appResources {
                    group.addTask {
                        let reviewsResource = try await client.fetchReviews(appID: app.id)
                        let iconURL = await client.fetchIconURL(bundleID: app.attributes.bundleId)
                        return await Self.mapApp(app, iconURL: iconURL, reviewsResource: reviewsResource)
                    }
                }

                var built: [ConnectApp] = []
                for try await app in group {
                    built.append(app)
                }
                return built.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            }

            apps = loadedApps
        } catch {
            apps = []
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private static func mapApp(
        _ app: AppResource,
        iconURL: URL?,
        reviewsResource: [CustomerReviewResource]
    ) -> ConnectApp {
        let reviews = reviewsResource.map { review in
            AppReview(
                id: review.id,
                rating: review.attributes.rating ?? 0,
                territoryCode: review.attributes.territory ?? "N/A",
                title: review.attributes.title,
                body: review.attributes.body,
                reviewerNickname: review.attributes.reviewerNickname,
                createdDate: review.attributes.createdDate
            )
        }

        let validRatings = reviews.filter { $0.rating > 0 }

        var grouped = Dictionary(grouping: validRatings, by: \.territoryCode)
            .map { territory, items -> TerritoryRating in
                let average = Double(items.reduce(0) { $0 + $1.rating }) / Double(items.count)
                return TerritoryRating(
                    territoryCode: territory,
                    reviewCount: items.count,
                    averageRating: average
                )
            }
        grouped.sort { $0.territoryCode < $1.territoryCode }

        let overallAverage: Double?
        if validRatings.isEmpty {
            overallAverage = nil
        } else {
            overallAverage = Double(validRatings.reduce(0) { $0 + $1.rating }) / Double(validRatings.count)
        }

        return ConnectApp(
            id: app.id,
            name: app.attributes.name,
            bundleID: app.attributes.bundleId,
            iconURL: iconURL,
            ratingsByTerritory: grouped,
            reviewCount: validRatings.count,
            averageRating: overallAverage,
            reviews: reviews.sorted { lhs, rhs in
                (lhs.createdDate ?? .distantPast) > (rhs.createdDate ?? .distantPast)
            }
        )
    }
}
