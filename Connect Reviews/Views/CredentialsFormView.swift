//
//  CredentialsFormView.swift
//  Connect Reviews
//
//  Created by Diego Rivera on 21/2/26.
//


import SwiftUI

struct CredentialsFormView: View {
    @ObservedObject var credentialsStore: CredentialsStore
    @Environment(\.dismiss) private var dismiss

    @State private var issuerID: String
    @State private var keyID: String
    @State private var privateKeyPEM: String
    @State private var validationMessage: String?

    init(credentialsStore: CredentialsStore) {
        self.credentialsStore = credentialsStore
        _issuerID = State(initialValue: credentialsStore.credentials?.issuerID ?? "")
        _keyID = State(initialValue: credentialsStore.credentials?.keyID ?? "")
        _privateKeyPEM = State(initialValue: credentialsStore.credentials?.privateKeyPEM ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("App Store Connect Credentials")
                .font(.title3.weight(.semibold))

            Text("Use an API key from App Store Connect: Users and Access > Integrations > App Store Connect API.")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                Text("Issuer ID")
                TextField("xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx", text: $issuerID)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Key ID")
                TextField("ABC123DEF4", text: $keyID)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Private Key (.p8 contents)")
                TextEditor(text: $privateKeyPEM)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 220)
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                    }
            }

            if let validationMessage {
                Text(validationMessage)
                    .foregroundStyle(.red)
                    .font(.callout)
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                Button("Save") {
                    do {
                        try credentialsStore.save(
                            issuerID: issuerID,
                            keyID: keyID,
                            privateKeyPEM: privateKeyPEM
                        )
                        dismiss()
                    } catch {
                        validationMessage = error.localizedDescription
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 640, minHeight: 520)
    }

    private func fillAppleReviewCredentials() {
        let demo = AppStoreConnectCredentials.appleReviewDemo
        issuerID = demo.issuerID
        keyID = demo.keyID
        privateKeyPEM = demo.privateKeyPEM
        validationMessage = nil
    }
}
