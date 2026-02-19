//
//  ConnectReviewsApp.swift
//  Connect Reviews
//
//  Created by Diego Rivera on 16/2/26.
//

import SwiftUI

@main
struct ConnectReviewsApp: App {
    @StateObject private var credentialsStore = CredentialsStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(credentialsStore)
        }
        .commands {
            AccountCommands(credentialsStore: credentialsStore)
        }
    }
}

struct AccountCommands: Commands {
    @ObservedObject var credentialsStore: CredentialsStore

    var body: some Commands {
        CommandMenu("Account") {
            Button("App Store Connect Credentials...") {
                credentialsStore.beginEditingCredentials()
            }
            Divider()
            Button("Log Out and Wipe Credentials") {
                credentialsStore.clearCredentials()
            }
            .disabled(!credentialsStore.hasCredentials)
        }
    }
}
