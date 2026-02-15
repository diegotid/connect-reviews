//
//  ContentView.swift
//  Connect Reviews
//
//  Created by Diego Rivera on 16/2/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var store = ConnectStore()
    @State private var selectedAppID: String?

    private var selectedApp: ConnectApp? {
        guard let selectedAppID else { return nil }
        return store.apps.first(where: { $0.id == selectedAppID })
    }

    var body: some View {
        NavigationSplitView {
            List(store.apps, selection: $selectedAppID) { app in
                HStack(spacing: 12) {
                    AppIconView(url: app.iconURL, size: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(app.name)
                            .font(.headline)
                        Text(app.bundleID)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .tag(app.id)
            }
            .navigationTitle("Apps")
        } detail: {
            Group {
                if store.isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Loading App Store Connect data...")
                            .foregroundStyle(.secondary)
                    }
                } else if let errorMessage = store.errorMessage {
                    VStack(spacing: 10) {
                        Text("Failed to load")
                            .font(.headline)
                        Text(errorMessage)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 560)
                    }
                    .padding()
                } else if let app = selectedApp {
                    AppDetailView(app: app)
                } else if let firstApp = store.apps.first {
                    AppDetailView(app: firstApp)
                } else {
                    ContentUnavailableView("No apps found", systemImage: "app.badge")
                }
            }
            .navigationTitle(selectedApp?.name ?? "Connect Reviews")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        Task { await store.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help("Refresh")
                    .disabled(store.isLoading)
                }
            }
        }
        .task {
            await store.refresh()
            if selectedAppID == nil {
                selectedAppID = store.apps.first?.id
            }
        }
    }
}

#Preview {
    ContentView()
}

private struct AppDetailView: View {
    let app: ConnectApp

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 14) {
                    AppIconView(url: app.iconURL, size: 64)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(app.name)
                            .font(.title2.bold())
                        Text(app.bundleID)
                            .foregroundStyle(.secondary)
                    }
                }

                GroupBox("Overall rating from reviews") {
                    HStack {
                        Text("Count: \(app.reviewCount)")
                        Spacer()
                        Text("Average: \(formatRating(app.averageRating))")
                    }
                    .font(.headline)
                    .padding(.top, 4)
                }

                GroupBox("Ratings by country/region") {
                    if app.ratingsByTerritory.isEmpty {
                        Text("No ratings available.")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(app.ratingsByTerritory) { entry in
                                HStack {
                                    Text(entry.territoryCode)
                                        .frame(width: 80, alignment: .leading)
                                        .font(.system(.body, design: .monospaced))
                                    Text("Count: \(entry.reviewCount)")
                                    Spacer()
                                    Text("Avg: \(formatRating(entry.averageRating))")
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }

                GroupBox("Reviews") {
                    if app.reviews.isEmpty {
                        Text("No reviews found.")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(app.reviews) { review in
                                VStack(alignment: .leading, spacing: 5) {
                                    HStack {
                                        Text(String(repeating: "★", count: max(review.rating, 0)))
                                            .foregroundStyle(.yellow)
                                        Text("(\(review.rating))")
                                            .foregroundStyle(.secondary)
                                        Text(review.territoryCode)
                                            .font(.system(.caption, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        if let date = review.createdDate {
                                            Text(date, style: .date)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }

                                    if let title = review.title, !title.isEmpty {
                                        Text(title)
                                            .font(.headline)
                                    }
                                    if let body = review.body, !body.isEmpty {
                                        Text(body)
                                            .font(.body)
                                    }
                                    if let reviewer = review.reviewerNickname, !reviewer.isEmpty {
                                        Text("by \(reviewer)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 8)

                                Divider()
                            }
                        }
                        .padding(.top, 4)
                    }
                }
            }
            .padding(20)
        }
    }

    private func formatRating(_ rating: Double?) -> String {
        guard let rating else { return "N/A" }
        return String(format: "%.2f", rating)
    }
}

private struct AppIconView: View {
    let url: URL?
    let size: CGFloat

    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    ZStack {
                        RoundedRectangle(cornerRadius: size * 0.22)
                            .fill(.quinary)
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            } else {
                RoundedRectangle(cornerRadius: size * 0.22)
                    .fill(.quinary)
                    .overlay {
                        Image(systemName: "app")
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
        .overlay {
            RoundedRectangle(cornerRadius: size * 0.22)
                .strokeBorder(.black.opacity(0.08))
        }
    }
}
