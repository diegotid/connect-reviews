//
//  ConnectReviewsRatingsWidget.swift
//  Connect Reviews
//
//  Created by Diego Rivera on 4/3/26.
//

import WidgetKit
import SwiftUI

struct ConnectReviewsRatingsWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: ConnectReviewsWidgetConstants.kind,
            intent: ConnectReviewsRatingsWidgetIntent.self,
            provider: ConnectReviewsRatingsWidgetProvider()
        ) { entry in
            ConnectReviewsRatingsWidgetView(entry: entry)
        }
        .configurationDisplayName("Connect Reviews")
        .description("Shows the average ratings for three selected Ready for Sale apps.")
        .supportedFamilies([.systemSmall])
    }
}

struct ConnectReviewsRatingsWidgetView: View {
    let entry: ConnectReviewsRatingsWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if entry.apps.isEmpty {
                Text(entry.errorMessage ?? "Open Connect Reviews to load apps.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(entry.apps) { app in
                        VStack(alignment: .leading, spacing: 1) {
                            Text(app.name)
                                .lineLimit(1)
                                .padding(.bottom, 2)
                            if let averageRating = app.averageRating {
                                WidgetStarRating(
                                    rating: averageRating,
                                    size: 9,
                                    ratingCount: app.totalRatingsCount
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
