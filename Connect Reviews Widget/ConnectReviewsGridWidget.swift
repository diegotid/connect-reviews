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
        AppIntentConfiguration(
            kind: ConnectReviewsWidgetConstants.gridKind,
            intent: ConnectReviewsGridWidgetIntent.self,
            provider: ConnectReviewsGridWidgetProvider()
        ) { entry in
            ConnectReviewsGridWidgetView(entry: entry)
        }
        .configurationDisplayName("Connect Reviews Grid")
        .description("Shows a grid of app names and average ratings.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .containerBackgroundRemovable()
    }
}

struct ConnectReviewsGridWidgetView: View {
    @Environment(\.showsWidgetContainerBackground) private var showsWidgetContainerBackground
    @Environment(\.widgetFamily) private var widgetFamily

    let entry: ConnectReviewsRatingsWidgetEntry

    private let gridSpacing: CGFloat = 6

    private var displayedApps: [ConnectReviewsApplication] {
        Array(entry.apps.prefix(maxDisplayedAppCount))
    }

    private var maxDisplayedAppCount: Int {
        switch widgetFamily {
        case .systemMedium:
            return 8
        default:
            return 4
        }
    }

    private var columnCount: Int {
        switch widgetFamily {
        case .systemMedium:
            return 4
        default:
            return 2
        }
    }

    private var columns: [GridItem] {
        switch widgetFamily {
        case .systemSmall:
            return [
                GridItem(.fixed(72), spacing: gridSpacing),
                GridItem(.fixed(72), spacing: gridSpacing)
            ]
        default:
            return Array(repeating: GridItem(.flexible(), spacing: gridSpacing), count: columnCount)
        }
    }

    private var gridPadding: CGFloat {
        showsWidgetContainerBackground ? 0 : 8
    }

    private var usesSparseLayout: Bool {
        switch widgetFamily {
        case .systemSmall:
            return displayedApps.count == 1
        case .systemMedium:
            return displayedApps.count < maxDisplayedAppCount
        default:
            return false
        }
    }

    var body: some View {
        Group {
            if displayedApps.isEmpty {
                Text(entry.errorMessage ?? "Open Connect Reviews to load apps.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(gridPadding)
            } else if usesSparseLayout {
                sparseLayout
            } else {
                regularGridLayout
            }
        }
        .containerBackground(for: .widget) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.fill.tertiary)
        }
    }

    @ViewBuilder
    private var sparseLayout: some View {
        switch widgetFamily {
        case .systemSmall:
            ConnectReviewsGridCell(app: displayedApps[0], style: .hero)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(gridPadding)
        case .systemMedium:
            if displayedApps.count <= 2 {
                mediumPromotedRoomsLayout
            } else if displayedApps.count <= 5 {
                mediumMixedRoomsLayout
            } else {
                mediumFullGridLayout(apps: displayedApps, placeholderCount: maxDisplayedAppCount - displayedApps.count)
            }
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var regularGridLayout: some View {
        switch widgetFamily {
        case .systemMedium:
            mediumFullGridLayout(apps: displayedApps, placeholderCount: maxDisplayedAppCount - displayedApps.count)
        default:
            LazyVGrid(columns: columns, spacing: gridSpacing) {
                ForEach(displayedApps) { app in
                    ConnectReviewsGridCell(app: app, style: .regular)
                        .aspectRatio(1, contentMode: .fit)
                }
                if displayedApps.count < maxDisplayedAppCount {
                    ForEach(0..<(maxDisplayedAppCount - displayedApps.count), id: \.self) { _ in
                        Color.clear
                            .aspectRatio(1, contentMode: .fit)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(gridPadding)
        }
    }

    private var mediumPromotedRoomsLayout: some View {
        HStack(spacing: gridSpacing) {
            ForEach(displayedApps) { app in
                ConnectReviewsGridCell(app: app, style: .promoted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            if displayedApps.count == 1 {
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(gridPadding)
    }

    private var mediumMixedRoomsLayout: some View {
        GeometryReader { proxy in
            let roomHeight = max((proxy.size.height - gridSpacing / 2) / 2, 0)
            HStack(spacing: gridSpacing) {
                ConnectReviewsGridCell(app: displayedApps[0], style: .promoted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: gridSpacing),
                        GridItem(.flexible(), spacing: gridSpacing)
                    ],
                    spacing: gridSpacing
                ) {
                    ForEach(Array(displayedApps.dropFirst())) { app in
                        ConnectReviewsGridCell(app: app, style: .compact)
                            .frame(height: roomHeight)
                    }
                    ForEach(0..<(5 - displayedApps.count), id: \.self) { _ in
                        Color.clear
                            .frame(height: roomHeight)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.top, -3)
    }

    private func mediumFullGridLayout(
        apps: [ConnectReviewsApplication],
        placeholderCount: Int
    ) -> some View {
        GeometryReader { proxy in
            let rowHeight = max((proxy.size.height - gridSpacing) / 2, 0)

            LazyVGrid(columns: columns, spacing: gridSpacing) {
                ForEach(apps) { app in
                    ConnectReviewsGridCell(app: app, style: .compact)
                        .frame(height: rowHeight)
                }

                if placeholderCount > 0 {
                    ForEach(0..<placeholderCount, id: \.self) { _ in
                        Color.clear
                            .frame(height: rowHeight)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .padding(gridPadding)
    }
}
