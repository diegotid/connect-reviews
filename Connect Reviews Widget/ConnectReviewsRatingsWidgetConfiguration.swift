//
//  ConnectReviewsRatingsWidgetConfiguration.swift
//  Connect Reviews
//
//  Created by Codex on 13/3/26.
//

import AppIntents
import WidgetKit

struct ConnectReviewsAppEntity: AppEntity, Identifiable {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "App")
    static var defaultQuery = ConnectReviewsAppEntityQuery()

    let id: String
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct ConnectReviewsAppEntityQuery: EntityQuery {
    func entities(for identifiers: [ConnectReviewsAppEntity.ID]) async throws -> [ConnectReviewsAppEntity] {
        let apps = try await fetchApps()
        let appsByID = Dictionary(uniqueKeysWithValues: apps.map { ($0.id, $0) })

        return identifiers.compactMap { appsByID[$0] }
    }

    func suggestedEntities() async throws -> [ConnectReviewsAppEntity] {
        try await fetchApps()
    }

    private func fetchApps() async throws -> [ConnectReviewsAppEntity] {
        let apps = try await ConnectReviewsWidgetDataLoader().loadSelectableApps()
        return apps.map { app in
            ConnectReviewsAppEntity(id: app.id, name: app.name)
        }
    }
}

struct ConnectReviewsRatingsWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Displayed Apps"
    static var description = IntentDescription("Choose which three apps appear in the ratings widget.")

    @Parameter(title: "First App")
    var firstApp: ConnectReviewsAppEntity?

    @Parameter(title: "Second App")
    var secondApp: ConnectReviewsAppEntity?

    @Parameter(title: "Third App")
    var thirdApp: ConnectReviewsAppEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Show \(\.$firstApp), \(\.$secondApp), and \(\.$thirdApp)")
    }

    var selectedAppIDs: [String] {
        [firstApp?.id, secondApp?.id, thirdApp?.id].compactMap { $0 }
    }
}

struct ConnectReviewsRatingsWidgetProvider: AppIntentTimelineProvider {
    typealias Entry = ConnectReviewsRatingsWidgetEntry
    typealias Intent = ConnectReviewsRatingsWidgetIntent

    private let dataLoader = ConnectReviewsWidgetDataLoader()

    func placeholder(in context: Context) -> ConnectReviewsRatingsWidgetEntry {
        ConnectReviewsRatingsWidgetEntry(
            date: Date(),
            vendorName: "Apps",
            apps: [
                ConnectReviewsApplication(
                    id: "placeholder-1",
                    name: "Sample App",
                    bundleID: "studio.cuatro.sample",
                    iconURL: nil,
                    iconData: nil,
                    averageRating: 4.2,
                    totalRatingsCount: 128
                ),
                ConnectReviewsApplication(
                    id: "placeholder-2",
                    name: "Second App",
                    bundleID: "studio.cuatro.second",
                    iconURL: nil,
                    iconData: nil,
                    averageRating: 4.8,
                    totalRatingsCount: 64
                ),
                ConnectReviewsApplication(
                    id: "placeholder-3",
                    name: "Third App",
                    bundleID: "studio.cuatro.third",
                    iconURL: nil,
                    iconData: nil,
                    averageRating: 3.9,
                    totalRatingsCount: 256
                )
            ],
            errorMessage: nil
        )
    }

    func snapshot(for configuration: ConnectReviewsRatingsWidgetIntent, in context: Context) async -> ConnectReviewsRatingsWidgetEntry {
        await dataLoader.load(selectedAppIDs: configuration.selectedAppIDs, maxCount: 3)
    }

    func timeline(for configuration: ConnectReviewsRatingsWidgetIntent, in context: Context) async -> Timeline<ConnectReviewsRatingsWidgetEntry> {
        let entry = await dataLoader.load(selectedAppIDs: configuration.selectedAppIDs, maxCount: 3)
        let nextRefresh = Date().addingTimeInterval(ConnectReviewsWidgetConstants.refreshInterval)
        return Timeline(entries: [entry], policy: .after(nextRefresh))
    }
}

struct ConnectReviewsGridWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Displayed Apps"
    static var description = IntentDescription("Choose up to eight apps that appear in the grid widget.")

    @Parameter(title: "First App")
    var firstApp: ConnectReviewsAppEntity?

    @Parameter(title: "Second App")
    var secondApp: ConnectReviewsAppEntity?

    @Parameter(title: "Third App")
    var thirdApp: ConnectReviewsAppEntity?

    @Parameter(title: "Fourth App")
    var fourthApp: ConnectReviewsAppEntity?

    @Parameter(title: "Fifth App")
    var fifthApp: ConnectReviewsAppEntity?

    @Parameter(title: "Sixth App")
    var sixthApp: ConnectReviewsAppEntity?

    @Parameter(title: "Seventh App")
    var seventhApp: ConnectReviewsAppEntity?

    @Parameter(title: "Eighth App")
    var eighthApp: ConnectReviewsAppEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Show \(\.$firstApp), \(\.$secondApp), \(\.$thirdApp), \(\.$fourthApp), \(\.$fifthApp), \(\.$sixthApp), \(\.$seventhApp), and \(\.$eighthApp)")
    }

    var selectedAppIDs: [String] {
        [
            firstApp?.id,
            secondApp?.id,
            thirdApp?.id,
            fourthApp?.id,
            fifthApp?.id,
            sixthApp?.id,
            seventhApp?.id,
            eighthApp?.id
        ].compactMap { $0 }
    }
}

struct ConnectReviewsGridWidgetProvider: AppIntentTimelineProvider {
    typealias Entry = ConnectReviewsRatingsWidgetEntry
    typealias Intent = ConnectReviewsGridWidgetIntent

    private let dataLoader = ConnectReviewsWidgetDataLoader()

    func placeholder(in context: Context) -> ConnectReviewsRatingsWidgetEntry {
        ConnectReviewsRatingsWidgetEntry(
            date: Date(),
            vendorName: "Apps",
            apps: [
                ConnectReviewsApplication(
                    id: "placeholder-1",
                    name: "Sample App",
                    bundleID: "studio.cuatro.sample",
                    iconURL: nil,
                    iconData: nil,
                    averageRating: 4.2,
                    totalRatingsCount: 128
                ),
                ConnectReviewsApplication(
                    id: "placeholder-2",
                    name: "Second App",
                    bundleID: "studio.cuatro.second",
                    iconURL: nil,
                    iconData: nil,
                    averageRating: 4.8,
                    totalRatingsCount: 64
                ),
                ConnectReviewsApplication(
                    id: "placeholder-3",
                    name: "Third App",
                    bundleID: "studio.cuatro.third",
                    iconURL: nil,
                    iconData: nil,
                    averageRating: 3.9,
                    totalRatingsCount: 256
                ),
                ConnectReviewsApplication(
                    id: "placeholder-4",
                    name: "Fourth App",
                    bundleID: "studio.cuatro.fourth",
                    iconURL: nil,
                    iconData: nil,
                    averageRating: 4.6,
                    totalRatingsCount: 93
                )
            ],
            errorMessage: nil
        )
    }

    func snapshot(for configuration: ConnectReviewsGridWidgetIntent, in context: Context) async -> ConnectReviewsRatingsWidgetEntry {
        await dataLoader.load(selectedAppIDs: configuration.selectedAppIDs, maxCount: 8)
    }

    func timeline(for configuration: ConnectReviewsGridWidgetIntent, in context: Context) async -> Timeline<ConnectReviewsRatingsWidgetEntry> {
        let entry = await dataLoader.load(selectedAppIDs: configuration.selectedAppIDs, maxCount: 8)
        let nextRefresh = Date().addingTimeInterval(ConnectReviewsWidgetConstants.refreshInterval)
        return Timeline(entries: [entry], policy: .after(nextRefresh))
    }
}
