//
//  ContentView.swift
//  Connect Reviews
//
//  Created by Diego Rivera on 16/2/26.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var credentialsStore: CredentialsStore
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
        Group {
            if credentialsStore.hasCredentials {
                authenticatedContent
            } else {
                CredentialsOnboardingView {
                    credentialsStore.beginEditingCredentials()
                }
            }
        }
        .sheet(isPresented: $credentialsStore.isPresentingEditor) {
            CredentialsFormView(credentialsStore: credentialsStore)
        }
        .task(id: credentialsStore.credentials) {
            guard credentialsStore.hasCredentials else { return }
            await refresh()
        }
        .onChange(of: credentialsStore.credentials) { _, newValue in
            guard newValue == nil else { return }
            selectedAppID = nil
            store.clearData()
        }
        .onChange(of: store.apps) { _, _ in
            if let selectedAppID, store.apps.contains(where: { $0.id == selectedAppID }) {
                return
            }
            self.selectedAppID = store.apps.first?.id
        }
    }

    private var authenticatedContent: some View {
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
            .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 420)
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
                        Task { await refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help("Refresh")
                    .disabled(store.isLoading)
                }
            }
        }
    }

    private func appStoreConnectURL(for app: ConnectApp) -> URL? {
        URL(string: "https://appstoreconnect.apple.com/apps/\(app.id)/appstore")
    }

    private func refresh() async {
        guard let credentials = credentialsStore.credentials else { return }
        await store.refresh(using: credentials)
        if selectedAppID == nil {
            selectedAppID = store.apps.first?.id
        }
    }
}

private struct CredentialsOnboardingView: View {
    let onSetupTapped: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "person.badge.key")
                .font(.system(size: 44))
                .foregroundStyle(.tint)

            Text("Connect your App Store Connect API key")
                .font(.title3.weight(.semibold))

            Text("Connect Reviews needs your Issuer ID, Key ID, and private key to read your apps, ratings, and reviews from App Store Connect.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 580)

            Text("Find these in App Store Connect under Users and Access > Integrations > App Store Connect API. Create an API key, then copy Issuer ID + Key ID and paste the downloaded .p8 private key.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 580)

            Button("Set Up Credentials") {
                onSetupTapped()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(28)
    }
}



#Preview {
    ContentView()
        .environmentObject(CredentialsStore())
}
