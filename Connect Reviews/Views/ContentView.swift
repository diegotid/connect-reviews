//
//  ContentView.swift
//  Connect Reviews
//
//  Created by Diego Rivera on 16/2/26.
//

import SwiftUI
import AppKit
import Combine

struct ContentView: View {
    @StateObject private var store = ConnectStore()
    @State private var selectedAppID: String?
    @Environment(\.openURL) private var openURL

    private var selectedApp: ConnectApp? {
        guard let selectedAppID else { return nil }
        return store.apps.first(where: { $0.id == selectedAppID })
    }

    private var displayedApp: ConnectApp? {
        selectedApp ?? store.apps.first
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                SidebarHeader(
                    title: store.vendorDisplayName,
                    subtitle: "Ready for Sale"
                )
                List(store.apps, selection: $selectedAppID) { app in
                    HStack(spacing: 12) {
                        AppIcon(url: app.iconURL, size: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(app.name)
                                .font(.headline)
                            if let averageRating = app.averageRating {
                                StarRating(rating: averageRating,
                                           ratingCount: app.totalRatingsCount,
                                           size: 9)
                            }
                        }
                    }
                    .tag(app.id)
                }
            }
            .navigationTitle("")
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
                } else if let app = displayedApp {
                    AppDetail(app: app)
                } else {
                    ContentUnavailableView("No apps found", systemImage: "app.badge")
                }
            }
            .navigationTitle(displayedApp?.name ?? "Connect Reviews")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        guard let app = displayedApp,
                              let url = appStoreConnectURL(for: app)
                        else { return }
                        openURL(url)
                    } label: {
                        Image(systemName: "arrow.up.right.square")
                    }
                    .help("Open in App Store Connect")
                    .disabled(displayedApp == nil)
                }
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
        .onChange(of: store.apps) { _, _ in
            if let selectedAppID, store.apps.contains(where: { $0.id == selectedAppID }) {
                return
            }
            self.selectedAppID = store.apps.first?.id
        }
    }

    private func appStoreConnectURL(for app: ConnectApp) -> URL? {
        URL(string: "https://appstoreconnect.apple.com/apps/\(app.id)/appstore")
    }
}

#Preview {
    ContentView()
}
