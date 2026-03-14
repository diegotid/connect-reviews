//
//  ConnectReviewsGridWidget.swift
//  Connect Reviews
//
//  Created by Diego Rivera on 4/3/26.
//

import SwiftUI
import WidgetKit

struct ConnectReviewsGridWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: ConnectReviewsWidgetConstants.gridKind,
            provider: ConnectReviewsWidgetProvider()
        ) { entry in
            ConnectReviewsGridWidgetView(entry: entry)
        }
        .configurationDisplayName("Connect Reviews Grid")
        .description("Shows a 2x2 grid of app names and average ratings.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct ConnectReviewsGridWidgetView: View {
    let entry: ConnectReviewsRatingsWidgetEntry

    private let columns = [
        GridItem(.fixed(72), spacing: 6),
        GridItem(.fixed(72), spacing: 6)
    ]

    private var displayedApps: [ConnectReviewsApplication] {
        Array(entry.apps.prefix(4))
    }

    var body: some View {
        Group {
            if displayedApps.isEmpty {
                Text(entry.errorMessage ?? "Open Connect Reviews to load apps.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                LazyVGrid(columns: columns, spacing: 40) {
                    ForEach(displayedApps) { app in
                        ConnectReviewsGridCell(app: app)
                    }

                    if displayedApps.count < 4 {
                        ForEach(0..<(4 - displayedApps.count), id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(.clear)
                        }
                    }
                }
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}
