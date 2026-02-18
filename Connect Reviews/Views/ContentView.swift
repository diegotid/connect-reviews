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

    private var selectedApp: ConnectApp? {
        guard let selectedAppID else { return nil }
        return store.apps.first(where: { $0.id == selectedAppID })
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
                } else if let app = selectedApp {
                    AppDetail(app: app)
                } else if let firstApp = store.apps.first {
                    AppDetail(app: firstApp)
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
        .onChange(of: store.apps) { _, _ in
            if let selectedAppID, store.apps.contains(where: { $0.id == selectedAppID }) {
                return
            }
            self.selectedAppID = store.apps.first?.id
        }
    }
}

#Preview {
    ContentView()
}
