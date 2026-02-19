import Foundation
import Combine

@MainActor
final class ConnectStore: ObservableObject {
    @Published private(set) var apps: [ConnectApp] = []
    @Published private(set) var vendorDisplayName = "Apps"
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    func refresh() async {
        isLoading = true
        errorMessage = nil

        do {
            let credentials = try CredentialsLoader.load()
            let client = AppStoreConnectClient(credentials: credentials)
            let appResources = try await client.fetchApps()
            async let vendorNameTask = resolveVendorName(from: appResources, client: client)

            let loadedApps = try await withThrowingTaskGroup(of: ConnectApp?.self) { group in
                for app in appResources {
                    group.addTask {
                        let versionsResource = (try? await client.fetchAppStoreVersions(appID: app.id)) ?? []
                        let states = versionsResource
                            .compactMap(\.attributes.appStoreState)
                            .filter { !$0.isEmpty }
                        guard states.contains("READY_FOR_SALE") else {
                            return nil
                        }

                        async let reviewsAndRatingsTask = client.fetchReviewsAndRatings(appID: app.id)
                        async let iTunesMetadataTask = client.fetchITunesMetadataAcrossMainTerritories(
                            appID: app.id,
                            bundleID: app.attributes.bundleId
                        )
                        let iTunesMetadata = await iTunesMetadataTask
                        let reviewsAndRatings = (try? await reviewsAndRatingsTask) ?? (reviews: [], ratings: [])

                        return await Self.mapApp(
                            app,
                            iconURL: iTunesMetadata?.iconURL,
                            iTunesMetadata: iTunesMetadata,
                            reviewsResource: reviewsAndRatings.reviews,
                            storefrontRatings: reviewsAndRatings.ratings,
                            appStoreStates: states
                        )
                    }
                }

                var built: [ConnectApp] = []
                for try await app in group {
                    if let app {
                        built.append(app)
                    }
                }
                return built.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            }

            apps = loadedApps
            vendorDisplayName = await vendorNameTask
        } catch {
            apps = []
            vendorDisplayName = "Apps"
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func resolveVendorName(
        from appResources: [AppResource],
        client: AppStoreConnectClient
    ) async -> String {
        guard let app = appResources.first else { return "Apps" }
        guard let vendorName = await client.fetchVendorName(appID: app.id, bundleID: app.attributes.bundleId) else {
            return "Apps"
        }
        let trimmed = vendorName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Apps" : trimmed
    }

    private static func mapApp(
        _ app: AppResource,
        iconURL: URL?,
        iTunesMetadata: ITunesMetadataResult?,
        reviewsResource: [CustomerReviewResource],
        storefrontRatings: [TerritoryRating],
        appStoreStates: [String]
    ) -> ConnectApp {
        let reviews = reviewsResource.map { review in
            AppReview(
                id: review.id,
                rating: review.attributes.rating ?? 0,
                territoryCode: review.attributes.territory.map { String($0.prefix(2)) } ?? "N/A",
                title: review.attributes.title,
                body: review.attributes.body,
                reviewerNickname: review.attributes.reviewerNickname,
                createdDate: review.attributes.createdDate
            )
        }

        let totalRatingCount: Int
        let overallAverage: Double?
        let hasAllRatingsCoverage: Bool

        let normalizedRatings: [TerritoryRating]
        let storefrontTotalCount: Int
        let storefrontAverage: Double?
        if !storefrontRatings.isEmpty {
            normalizedRatings = storefrontRatings
            storefrontTotalCount = normalizedRatings.reduce(0) { $0 + $1.reviewCount }
            let weightedSum = normalizedRatings.reduce(0.0) { partial, item in
                partial + (item.averageRating * Double(item.reviewCount))
            }
            storefrontAverage = storefrontTotalCount > 0 ? (weightedSum / Double(storefrontTotalCount)) : nil
        } else {
            let validRatings = reviews.filter { $0.rating > 0 }
            var fallback = Dictionary(grouping: validRatings, by: \.territoryCode)
                .map { territory, items -> TerritoryRating in
                    let average = Double(items.reduce(0) { $0 + $1.rating }) / Double(items.count)
                    return TerritoryRating(
                        territoryCode: territory,
                        reviewCount: items.count,
                        averageRating: average
                    )
                }
            fallback.sort { $0.territoryCode < $1.territoryCode }
            normalizedRatings = fallback
            storefrontTotalCount = 0
            storefrontAverage = nil
        }

        if let iTunesCount = iTunesMetadata?.userRatingCount, iTunesCount > 0 {
            totalRatingCount = iTunesCount
            overallAverage = iTunesMetadata?.averageUserRating
            hasAllRatingsCoverage = true
        } else if !storefrontRatings.isEmpty {
            totalRatingCount = storefrontTotalCount
            overallAverage = storefrontAverage
            hasAllRatingsCoverage = true
        } else {
            let reviewRatings = reviews.filter { $0.rating > 0 }
            totalRatingCount = reviewRatings.count
            overallAverage = reviewRatings.isEmpty
                ? nil
                : Double(reviewRatings.reduce(0) { $0 + $1.rating }) / Double(reviewRatings.count)
            hasAllRatingsCoverage = false
        }

        let reviewsWithText = reviews.filter { review in
            let hasTitle = !(review.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let hasBody = !(review.body ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            return hasTitle || hasBody
        }
        let textReviewCount = reviewsWithText.count
        let ratingsFromReviewsCount = reviewsWithText.filter { $0.rating > 0 }.count
        let ratingsWithoutReviewCount =
            hasAllRatingsCoverage ? max(totalRatingCount - ratingsFromReviewsCount, 0) : nil
        let uniqueStates = Array(Set(appStoreStates)).sorted()
        let statePriority = [
            "READY_FOR_SALE",
            "READY_FOR_DISTRIBUTION",
            "PREORDER_READY_FOR_SALE",
            "PENDING_APPLE_RELEASE",
            "PENDING_DEVELOPER_RELEASE",
            "IN_REVIEW",
            "WAITING_FOR_REVIEW",
            "DEVELOPER_REJECTED",
            "REJECTED",
            "METADATA_REJECTED",
            "INVALID_BINARY",
            "PREPARE_FOR_SUBMISSION"
        ]
        let primaryState = statePriority.first(where: { uniqueStates.contains($0) }) ?? uniqueStates.first

        return ConnectApp(
            id: app.id,
            name: app.attributes.name,
            bundleID: app.attributes.bundleId,
            appStoreStates: uniqueStates,
            primaryAppStoreState: primaryState,
            iconURL: iconURL,
            ratingsByTerritory: normalizedRatings.sorted { $0.territoryCode < $1.territoryCode },
            hasAllRatingsCoverage: hasAllRatingsCoverage,
            totalRatingsCount: totalRatingCount,
            ratingsFromReviewsCount: ratingsFromReviewsCount,
            ratingsWithoutReviewCount: ratingsWithoutReviewCount,
            textReviewCount: textReviewCount,
            averageRating: overallAverage,
            reviews: reviews.sorted { lhs, rhs in
                (lhs.createdDate ?? .distantPast) > (rhs.createdDate ?? .distantPast)
            }
        )
    }
}
