//
//  ConnectReviewsWidgetDataLoader.swift
//  Connect Reviews
//
//  Created by Diego Rivera on 4/3/26.
//

import WidgetKit

actor ConnectReviewsWidgetDataLoader {
    func load() async -> ConnectReviewsRatingsWidgetEntry {
        do {
            let credentials = try WidgetCredentialsLoader.load()
            let client = WidgetAppStoreConnectClient(credentials: credentials)
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
                            app: ConnectReviewsApplication(
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

            return ConnectReviewsRatingsWidgetEntry(
                date: Date(),
                vendorName: vendorName,
                apps: sortedApps,
                errorMessage: nil
            )
        } catch {
            return ConnectReviewsRatingsWidgetEntry(
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
