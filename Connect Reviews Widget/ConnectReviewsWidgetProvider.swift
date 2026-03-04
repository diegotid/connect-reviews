//
//  ConnectReviewsWidgetProvider.swift
//  Connect Reviews
//
//  Created by Diego Rivera on 4/3/26.
//

import WidgetKit
import SwiftUI

struct ConnectReviewsWidgetProvider: TimelineProvider {
    private let dataLoader = ConnectReviewsWidgetDataLoader()

    func placeholder(in context: Context) -> ConnectReviewsRatingsWidgetEntry {
        ConnectReviewsRatingsWidgetEntry(
            date: Date(),
            vendorName: "Apps",
            apps: [
                ConnectReviewsApplication(
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

    func getSnapshot(in context: Context, completion: @escaping (ConnectReviewsRatingsWidgetEntry) -> Void) {
        Task {
            completion(await dataLoader.load())
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ConnectReviewsRatingsWidgetEntry>) -> Void) {
        Task {
            let entry = await dataLoader.load()
            let nextRefresh = Date().addingTimeInterval(ConnectReviewsWidgetConstants.refreshInterval)
            completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
        }
    }
}
